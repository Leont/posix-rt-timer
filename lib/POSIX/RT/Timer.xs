/*
 * This software is copyright (c) 2010 by Leon Timmermans <leont@cpan.org>.
 *
 * This is free software; you can redistribute it and/or modify it under
 * the same terms as perl itself.
 *
 */

#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <signal.h>
#include <time.h>

#ifndef DEFAULT_SIGNO
#	define DEFAULT_SIGNO (SIGRTMIN + 3)
#endif


static void get_sys_error(char* buffer, size_t buffer_size) {
#ifdef _GNU_SOURCE
	const char* message = strerror_r(errno, buffer, buffer_size);
	if (message != buffer) {
		memcpy(buffer, message, buffer_size -1);
		buffer[buffer_size] = '\0';
	}
#else
	strerror_r(errno, buffer, buffer_size);
#endif
}

static void S_die_sys(pTHX_ const char* format) {
	char buffer[128];
	get_sys_error(buffer, sizeof buffer);
	Perl_croak(aTHX_ format, buffer);
}
#define die_sys(format) S_die_sys(aTHX_ format)


typedef struct { const char* key; clockid_t value; } map[];

static map clocks = {
	{ "monotonic", CLOCK_MONOTONIC },
	{ "realtime" , CLOCK_REALTIME  }
#ifdef CLOCK_PROCESS_CPUTIME_ID
	, { "process_cputime_id", CLOCK_PROCESS_CPUTIME_ID }
#endif
#ifdef CLOCK_THREAD_CPUTIME_ID
	, { "thread_cputime_id", CLOCK_THREAD_CPUTIME_ID }
#endif
};

static clockid_t S_get_clock(pTHX_ const char* clock_name) {
	int i;
	for (i = 0; i < sizeof clocks / sizeof *clocks; ++i) {
		if (strEQ(clock_name, clocks[i].key))
			return clocks[i].value;
	}
	Perl_croak(aTHX_ "No such timer '%s' known", clock_name);
}
#define get_clock(name) S_get_clock(aTHX_ name)

int S_get_signo(pTHX) {
	SV** tmp = hv_fetch(PL_modglobal, "POSIX::RT::Timer::SIGNO", 23, FALSE);
	return SvIV(*tmp);
}
#define get_signo() S_get_signo(aTHX)

static void init_event(struct sigevent* event, int signo, void* ptr) {
	event->sigev_notify          = SIGEV_SIGNAL;
	event->sigev_signo           = signo;
	event->sigev_value.sival_ptr = ptr;
}

CV* get_callback(pTHX_ SV* arg) {
	HV* stash;
	GV* gv;
	CV* ret = sv_2cv(arg, &stash, &gv, 0);
	if (!ret)
		Perl_croak(aTHX_ "Can't make a codeval out of %s", SvPV_nolen(arg));
	return ret;
}


static MAGIC* S_get_magic(pTHX_ SV* ref, const char* funcname) {
	SV* value;
	MAGIC* magic;
	if (!SvROK(ref) || !(value = SvRV(ref)) || !SvMAGICAL(value) || (magic = mg_find(value, PERL_MAGIC_ext)) == NULL)
		Perl_croak(aTHX_ "Could not %s: this variable is not a timer", funcname);
	return magic;
}
#define get_magic(ref, funcname) S_get_magic(aTHX_ ref, funcname)
#define get_timer(ref, funcname) (*(timer_t*)get_magic(ref, funcname)->mg_ptr)


#define NANO_SECONDS 1000000000

static NV timespec_to_nv(struct timespec* time) {
	return time->tv_sec + time->tv_nsec / NANO_SECONDS;
}

static void nv_to_timespec(NV input, struct timespec* output) {
	output->tv_sec  = (time_t) floor(input);
	output->tv_nsec = (long) ((input - output->tv_sec) * NANO_SECONDS);
}


XS(callback) {
#ifdef dVAR
    dVAR; dXSARGS;
#else
    dXSARGS;
#endif
    PERL_UNUSED_VAR(cv); /* -W */
    PERL_UNUSED_VAR(ax); /* -Wall */

	SV* signal = ST(0);
	SV* action = ST(2);
    SP -= items;

	siginfo_t* info = (siginfo_t*) SvPV_nolen(action);
	SV* timer = (SV*)info->si_ptr;
	if (timer != 0) {
		MAGIC* magic = mg_find(timer, PERL_MAGIC_ext);
		SV* callback = (SV*) magic->mg_obj;
		PUSHMARK(SP);
		mXPUSHs(newRV_inc(timer));
		PUTBACK;
		call_sv(callback, GIMME_V);
		SPAGAIN;
	}
	PUTBACK;
}

void register_callback(pTHX) {
	dSP;

	CV* callback_cv = newXS("", callback, __FILE__);
	ENTER;
	SAVETMPS;
	
	PUSHMARK(SP);
	mXPUSHp("POSIX::SigSet", 13);
	PUTBACK;
	call_method("new", G_SCALAR);
	SPAGAIN;
	SV* sigset = POPs;
	
	PUSHMARK(SP);
	mXPUSHp("POSIX::SigAction", 16);
	mXPUSHs(newRV_noinc((SV*)callback_cv));
	XPUSHs(sigset);
	mXPUSHi(SA_SIGINFO);
	PUTBACK;
	call_method("new", G_SCALAR);
	SPAGAIN;
	SV* sigaction = POPs;

	PUSHMARK(SP);
	mXPUSHi(get_signo());
	XPUSHs(sigaction);
	PUTBACK;
	call_pv("POSIX::sigaction", G_VOID | G_DISCARD);
	SPAGAIN;

	FREETMPS;
	LEAVE;
}

MODULE = POSIX::RT::Timer				PACKAGE = POSIX::RT::Timer

PROTOTYPES: DISABLED

BOOT:
	SV* signo = get_sv("POSIX::RT::Timer::SIGNO", GV_ADD | GV_ADDMULTI);
	if (!SvOK(signo))
		sv_setiv(signo, DEFAULT_SIGNO);
	SvREADONLY_on(signo);
	hv_store(PL_modglobal, "POSIX::RT::Timer::SIGNO", 23, newSVsv(signo), 0);
	
	register_callback(aTHX);

SV*
create(class, clock_type, type, arg)
	const char* class;
	const char* clock_type;
	const char* type;
	SV* arg;
	PREINIT:
		clockid_t clockid;
		struct sigevent event;
		timer_t timer;
		SV *tmp;
		int signal;
		CV* callback;
	CODE:
		clockid = get_clock(clock_type);
		tmp = newSV(0);
		RETVAL = newRV_noinc(tmp);

		if (strEQ(type, "signal")) {
			init_event(&event, SvIV(arg), NULL);
			callback = NULL;
		}
		else if (strEQ(type, "callback")) {
			init_event(&event, get_signo(), tmp);
			callback = get_callback(aTHX_ arg);
		}
		else {
			Perl_croak(aTHX_ "Unknown type '%s'", type);
		}

		MAGIC* magic = sv_magicext(tmp, (SV*)callback, PERL_MAGIC_ext, NULL, (const char*)&timer, sizeof timer);
		if (timer_create(clockid, &event, (timer_t*) magic->mg_ptr) == -1) 
			die_sys("Couldn't create timer: %s");

		sv_bless(RETVAL, gv_stashpv(class, 0));
	OUTPUT:
		RETVAL

void*
get_clocks(class)
	SV* class;
	PREINIT:
		size_t i;
		const size_t max = sizeof clocks / sizeof *clocks;
	PPCODE:
		for (i = 0; i < max; ++i)
			mXPUSHp(clocks[i].key, strlen(clocks[i].key));
		XSRETURN(max);

void
get_time(self)
	SV* self;
	PREINIT:
		timer_t timer;
		struct itimerspec value;
	PPCODE:
		timer = get_timer(self, "get_time");
		if (timer_gettime(&timer, &value) == -1)
			die_sys("Couldn't get_time: %s");
		mXPUSHn(timespec_to_nv(&value.it_value));
		if (GIMME_V == G_ARRAY)
			mXPUSHn(timespec_to_nv(&value.it_interval));

void
set_time(self, new_value, new_interval = 0, abstime = 0)
	SV* self;
	NV new_value;
	NV new_interval;
	IV abstime;
	PREINIT:
		timer_t timer;
		struct itimerspec new_itimer, old_itimer;
	PPCODE:
		timer = get_timer(self, "set_time");
		nv_to_timespec(new_value, &new_itimer.it_value);
		nv_to_timespec(new_interval, &new_itimer.it_interval);
		if (timer_settime(&timer, (abstime ? TIMER_ABSTIME : 0), &new_itimer, &old_itimer) == -1)
			die_sys("Couldn't set_time: %s");
		mXPUSHn(timespec_to_nv(&old_itimer.it_value));
		if (GIMME_V == G_ARRAY)
			mXPUSHn(timespec_to_nv(&old_itimer.it_interval));

SV*
get_callback(self)
	SV* self;
	PREINIT:
	MAGIC* magic;
	CODE:
	magic = get_magic(self, "get_callback");
	if (magic->mg_obj) 
		RETVAL = SvREFCNT_inc(magic->mg_obj);
	else
		RETVAL = &PL_sv_undef;
	OUTPUT:
		RETVAL

SV*
set_callback(self, callback)
	SV* self;
	SV* callback;
	PREINIT:
	MAGIC* magic;
	CODE:
		magic = get_magic(self, "get_callback");
		if (!magic->mg_obj)
			Perl_croak(aTHX_ "Can't set callback for this timer object");
		RETVAL = magic->mg_obj;
		magic->mg_obj = SvREFCNT_inc((SV*)get_callback(aTHX_ callback));
	OUTPUT:
		RETVAL

IV
get_overrun(self)
	SV* self;
	PREINIT:
		timer_t timer;
	CODE:
		timer = get_timer(self, "get_overrun");
		RETVAL = timer_getoverrun(timer);
		if (RETVAL == -1) 
			die_sys("Couldn't get_overrun: %s");
	OUTPUT:
		RETVAL

void
DESTROY(self)
	SV* self;
	PREINIT:
		timer_t timer;
	CODE:
		timer = get_timer(self, "DESTROY");
		timer_delete(timer);
