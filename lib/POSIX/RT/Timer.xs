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
#include "ppport.h"

#include <signal.h>
#include <time.h>

#include "Clock_Timer.h"

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

static int timer_destroy(pTHX_ SV* var, MAGIC* magic) {
	if (timer_delete(*(timer_t*)magic->mg_ptr))
		die_sys("Can't delete timer: %s");
}

MGVTBL timer_magic = { NULL, NULL, NULL, NULL, timer_destroy };

static SV* S_create_timer(pTHX_ const char* class, clockid_t clockid, int signo, IV id) {
	struct sigevent event;
	timer_t timer;
	SV *tmp, *retval;

	tmp = newSV(0);
	retval = sv_2mortal(sv_bless(newRV_noinc(tmp), gv_stashpv(class, 0)));
	SvREADONLY_on(tmp);

	memset(&event, 0, sizeof(struct sigevent));
	event.sigev_notify          = SIGEV_SIGNAL;
	event.sigev_signo           = signo;
	event.sigev_value.sival_int = id;

	if (timer_create(clockid, &event, &timer) == -1) 
		die_sys("Couldn't create timer: %s");
	MAGIC* magic = sv_magicext(tmp, NULL, PERL_MAGIC_ext, &timer_magic, (const char*)&timer, sizeof timer);

	return retval;
}
#define create_timer(class, clockid, arg, id) S_create_timer(aTHX_ class, clockid, arg, id)

static SV* S_create_clock(pTHX_ clockid_t clockid, const char* class) {
	SV *tmp, *retval;
	tmp = newSViv(clockid);
	retval = newRV_noinc(tmp);
	sv_bless(retval, gv_stashpv(class, 0));
	SvREADONLY_on(tmp);
	return retval;
}
#define create_clock(clockid, class) S_create_clock(aTHX_ clockid, class)

#if defined(_POSIX_CLOCK_SELECTION) && _POSIX_CLOCK_SELECTION >= 0
static int my_clock_nanosleep(pTHX_ clockid_t clockid, int flags, const struct timespec* request, struct timespec* remain) {
	int ret;
	ret = clock_nanosleep(clockid, flags, request, remain);
	if (ret != 0) {
		errno = ret;
		if (ret != EINTR)
			die_sys("Could not sleep: %s");
	}
	return ret;
}
#endif

#define clock_nanosleep(clockid, flags, request, remain) my_clock_nanosleep(aTHX_ clockid, flags, request, remain)

#if defined(USE_ITHREADS) && defined(_POSIX_THREAD_CPUTIME) && _POSIX_THREAD_CPUTIME >= 0
static pthread_t* S_get_pthread(pTHX_ SV* thread_handle) {
	SV* tmp;
	pthread_t* ret;
	dSP;
	SAVETMPS;
	PUSHMARK(SP);
	PUSHs(thread_handle);
	PUTBACK;
	call_method("_handle", G_SCALAR);
	SPAGAIN;
	tmp = POPs;
	ret = INT2PTR(pthread_t* ,SvUV(tmp));
	FREETMPS;
	return ret;
}
#define get_pthread(handle) S_get_pthread(aTHX_ handle)
#endif

#define undef &PL_sv_undef

MODULE = POSIX::RT::Timer				PACKAGE = POSIX::RT::Timer

PROTOTYPES: DISABLED

void
_new(class, clock, signo, id)
	const char* class;
	SV* clock;
	IV signo;
	IV id;
	PREINIT:
		clockid_t clockid;
	PPCODE:
		clockid = SvROK(clock) ? get_clock(clock, "create timer") : get_clockid(SvPV_nolen(clock));
		XPUSHs(create_timer(class, clockid, signo, id));


void
get_timeout(self)
	SV* self;
	PREINIT:
		timer_t timer;
		struct itimerspec value;
	PPCODE:
		timer = get_timer(self, "get_timeout");
		if (timer_gettime(timer, &value) == -1)
			die_sys("Couldn't get_time: %s");
		mXPUSHn(timespec_to_nv(&value.it_value));
		if (GIMME_V == G_ARRAY)
			mXPUSHn(timespec_to_nv(&value.it_interval));

void
set_timeout(self, new_value, new_interval = 0, abstime = 0)
	SV* self;
	NV new_value;
	NV new_interval;
	IV abstime;
	PREINIT:
		timer_t timer;
		struct itimerspec new_itimer, old_itimer;
	PPCODE:
		timer = get_timer(self, "set_timeout");
		nv_to_timespec(new_value, &new_itimer.it_value);
		nv_to_timespec(new_interval, &new_itimer.it_interval);
		if (timer_settime(timer, (abstime ? TIMER_ABSTIME : 0), &new_itimer, &old_itimer) == -1)
			die_sys("Couldn't set_time: %s");
		mXPUSHn(timespec_to_nv(&old_itimer.it_value));
		if (GIMME_V == G_ARRAY)
			mXPUSHn(timespec_to_nv(&old_itimer.it_interval));

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

#if defined(_POSIX_CPUTIME) && _POSIX_CPUTIME >= 0
SV*
get_cpuclock(class, pid = undef)
	const char* class;
	SV* pid;
	PREINIT:
		clockid_t clockid;
	CODE:
		if (SvOK(pid) && SvROK(pid) && sv_derived_from(pid, "threads")) {
#if defined(USE_ITHREADS) && defined(_POSIX_THREAD_CPUTIME) && _POSIX_THREAD_CPUTIME >= 0
			pthread_t* handle = get_pthread(pid);
			if (pthread_getcpuclockid(*handle, &clockid) != 0)
				die_sys("Could not get cpuclock");
#else
			Perl_croak(aTHX_ "Can't get CPU time for threads");
#endif
		}
		else {
			if (clock_getcpuclockid(SvOK(pid) ? SvIV(pid) : 0, &clockid) != 0)
				die_sys("Could not get cpuclock");
		}
		
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
		if (clock_getres(clockid, &time) == -1)
			die_sys("Couldn't get resolution: %s");
		RETVAL = timespec_to_nv(&time);
	OUTPUT:
		RETVAL

#if defined(_POSIX_CLOCK_SELECTION) && _POSIX_CLOCK_SELECTION >= 0
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

#endif
