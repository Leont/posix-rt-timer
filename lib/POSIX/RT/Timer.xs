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
	{ "realtime" , CLOCK_REALTIME  },
	{ "monotonic", CLOCK_MONOTONIC }
#ifdef CLOCK_PROCESS_CPUTIME_ID
	, { "process_cputime_id", CLOCK_PROCESS_CPUTIME_ID }
#endif
#ifdef CLOCK_THREAD_CPUTIME_ID
	, { "thread_cputime_id", CLOCK_THREAD_CPUTIME_ID }
#endif
};

static clockid_t S_get_clockid(pTHX_ const char* clock_name) {
	int i;
	for (i = 0; i < sizeof clocks / sizeof *clocks; ++i) {
		if (strEQ(clock_name, clocks[i].key))
			return clocks[i].value;
	}
	Perl_croak(aTHX_ "No such timer '%s' known", clock_name);
}
#define get_clockid(name) S_get_clockid(aTHX_ name)

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

CV* create_callback(pTHX_ SV* arg) {
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

static clockid_t S_get_clock(pTHX_ SV* ref, const char* funcname) {
	SV* value;
	if (!SvROK(ref) || !(value = SvRV(ref)))
		Perl_croak(aTHX_ "Could not %s: this variable is not a clock", funcname);
	return SvIV(value);
}
#define get_clock(ref, func) S_get_clock(aTHX_ ref, func)

#define NANO_SECONDS 1000000000

static NV timespec_to_nv(struct timespec* time) {
	return time->tv_sec + time->tv_nsec / (double)NANO_SECONDS;
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
	else
		Perl_warn(aTHX_ "Got a signal without a value on slot %d\n", info->si_signo);
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

int timer_destroy(pTHX_ SV* var, MAGIC* magic) {
	if (timer_delete(*(timer_t*)magic->mg_ptr))
		die_sys("Can't delete timer: %s");
}

MGVTBL timer_magic = { NULL, NULL, NULL, NULL, timer_destroy };

SV* S_create_timer(pTHX_ const char* class, clockid_t clockid, const char* type, SV* arg) {
	struct sigevent event;
	timer_t timer;
	SV *tmp;
	SV* retval;
	CV* callback;

	tmp = newSV(0);
	retval = newRV_noinc(tmp);
	sv_2mortal(retval);

	if (strEQ(type, "signal")) {
		init_event(&event, SvIV(arg), NULL);
		callback = NULL;
	}
	else if (strEQ(type, "callback")) {
		init_event(&event, get_signo(), tmp);
		callback = create_callback(aTHX_ arg);
	}
	else
		Perl_croak(aTHX_ "Unknown type '%s'", type);

	if (timer_create(clockid, &event, &timer) == -1) 
		die_sys("Couldn't create timer: %s");
	MAGIC* magic = sv_magicext(tmp, (SV*)callback, PERL_MAGIC_ext, &timer_magic, (const char*)&timer, sizeof timer);

	sv_bless(retval, gv_stashpv(class, 0));
	return retval;
}
#define create_timer(class, clockid, type, arg) S_create_timer(aTHX_ class, clockid, type, arg)

SV* S_create_clock(pTHX_ clockid_t clockid, const char* class) {
	SV *tmp, *retval;
	tmp = newSViv(clockid);
	retval = newRV_noinc(tmp);
	sv_bless(retval, gv_stashpv(class, 0));
	SvREADONLY_on(tmp);
	return retval;
}
#define create_clock(clockid, class) S_create_clock(aTHX_ clockid, class)

int my_clock_nanosleep(pTHX_ clockid_t clockid, int flags, const struct timespec* request, struct timespec* remain) {
	U32 saved = PL_signals;
	int ret;
	PL_signals |= PERL_SIGNALS_UNSAFE_FLAG;
	ret = clock_nanosleep(clockid, flags, request, remain);
	PL_signals = saved;
	if (ret != 0 && ret != EINTR) {
		errno = ret;
		die_sys("Could not sleep: %s");
	}
	return ret;
}

#define clock_nanosleep(clockid, flags, request, remain) my_clock_nanosleep(aTHX_ clockid, flags, request, remain)

MODULE = POSIX::RT::Timer				PACKAGE = POSIX::RT::Timer

PROTOTYPES: DISABLED

BOOT:
	SV* signo = get_sv("POSIX::RT::Timer::SIGNO", GV_ADD | GV_ADDMULTI);
	if (!SvOK(signo))
		sv_setiv(signo, DEFAULT_SIGNO);
	SvREADONLY_on(signo);
	hv_store(PL_modglobal, "POSIX::RT::Timer::SIGNO", 23, newSVsv(signo), 0);
	
	register_callback(aTHX);

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
		magic = get_magic(self, "set_callback");
		if (!magic->mg_obj)
			Perl_croak(aTHX_ "Can't set callback for this timer object");
		RETVAL = magic->mg_obj;
		magic->mg_obj = SvREFCNT_inc((SV*)create_callback(aTHX_ callback));
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

MODULE = POSIX::RT::Timer				PACKAGE = POSIX::RT::Clock

PROTOTYPES: DISABLED

SV*
new(class, clock_type) 
	const char* class;
	const char* clock_type;
	CODE:
		RETVAL = create_clock(get_clockid(clock_type), class);
	OUTPUT:
		RETVAL

#ifdef linux
SV*
get_cpuclock(class, pid = 0)
	const char* class;
	IV pid;
	PREINIT:
		clockid_t clockid;
	CODE:
		if (clock_getcpuclockid(pid, &clockid) != 0)
			die_sys("Could not get cpuclock");
		RETVAL = create_clock(clockid, class);
	OUTPUT:
		RETVAL

#endif

void
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
_timer(self, class, type, arg)
	SV* self;
	const char* class;
	const char* type;
	SV* arg;
	PPCODE:
		XPUSHs(create_timer(class, get_clock(self, "timer"), type, arg));

NV
get_time(self)
	SV* self;
	PREINIT:
		clockid_t clockid;
		struct timespec time;
	CODE:
		clockid = get_clock(self, "get_time");
		if (clock_gettime(clockid, &time) == -1)
			die_sys("Couldn't get time: %s");
		RETVAL = timespec_to_nv(&time);
	OUTPUT:
		RETVAL

void
set_time(self, frac_time)
	SV* self;
	NV frac_time;
	PREINIT:
		clockid_t clockid;
		struct timespec time;
	CODE:
		clockid = get_clock(self, "set_time");
		nv_to_timespec(frac_time, &time);
		if (clock_settime(clockid, &time) == -1)
			die_sys("Couldn't set time: %s");

NV
get_resolution(self)
	SV* self;
	PREINIT:
		clockid_t clockid;
		struct timespec time;
	CODE:
		clockid = get_clock(self, "get_resolution");
		if (clock_gettime(clockid, &time) == -1)
			die_sys("Couldn't get resolution: %s");
		RETVAL = timespec_to_nv(&time);
	OUTPUT:
		RETVAL

NV
sleep(self, frac_time, abstime = 0)
	SV* self;
	NV frac_time;
	int abstime;
	PREINIT:
		clockid_t clockid;
		struct timespec sleep_time, remain_time;
		int flags;
	CODE:
		clockid = get_clock(self, "sleep");
		flags = abstime ? TIMER_ABSTIME : 0;
		nv_to_timespec(frac_time, &sleep_time);

		if (clock_nanosleep(clockid, flags, &sleep_time, &remain_time) == EINTR)
			RETVAL = abstime ? frac_time : timespec_to_nv(&remain_time);
		else 
			RETVAL = 0;
	OUTPUT:
		RETVAL

NV
sleep_deeply(self, frac_time, abstime = 0)
	SV* self;
	NV frac_time;
	int abstime;
	PREINIT:
		clockid_t clockid;
		struct timespec sleep_time;
		NV real_time;
	CODE:
		clockid = get_clock(self, "sleep_deeply");
		if (abstime)
			nv_to_timespec(frac_time, &sleep_time);
		else {
			if (clock_gettime(clockid, &sleep_time) == -1)
				die_sys("Couldn't get time: %s");
			nv_to_timespec(timespec_to_nv(&sleep_time) + frac_time, &sleep_time);
		}
		while (clock_nanosleep(clockid, TIMER_ABSTIME, &sleep_time, NULL) == EINTR);
		RETVAL = 0;
	OUTPUT:
		RETVAL
