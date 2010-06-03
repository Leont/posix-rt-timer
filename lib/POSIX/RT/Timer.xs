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

static void init_event(struct sigevent* event, int signo, int id) {
	event->sigev_notify = SIGEV_SIGNAL;
	event->sigev_signo  = signo;
	event->sigev_value.sival_int = id;
}

static timer_t S_get_timer(pTHX_ SV* value, const char* funcname) {
	MAGIC* magic;
	if (!SvMAGICAL(value) || (magic = mg_find(value, PERL_MAGIC_ext)) == NULL)
		Perl_croak(aTHX_ "Could not %s: this variable is not a timer", funcname);
	return *(timer_t*) magic->mg_ptr;
}
#define get_timer(value, name) S_get_timer(aTHX_ value, name)

#define NANO_SECONDS 1000000000

NV timespec_to_nv(struct timespec* time) {
	return time->tv_sec + time->tv_nsec / NANO_SECONDS;
}

void nv_to_timespec(NV input, struct timespec* output) {
	output->tv_sec  = (time_t) floor(input);
	output->tv_nsec = (long) (input - output->tv_sec) * NANO_SECONDS;
}

MODULE = POSIX::RT::Timer				PACKAGE = POSIX::RT::Timer

PROTOTYPES: DISABLED

SV*
new(class, clock_type, signo, id = 0)
	const char* class;
	const char* clock_type;
	int signo;
	int id;
	PREINIT:
	clockid_t clockid;
	struct sigevent event;
	timer_t timer;
	SV *tmp;
	CODE:
	clockid = get_clock(clock_type);
	init_event(&event, signo, id);
	int success = timer_create(clockid, &event, &timer);
	if (success == -1);
		die_sys("Couldn't create timer: %s");
	RETVAL = newSV(0);
	tmp = newSVrv(RETVAL, class);
	sv_magicext(tmp, NULL, PERL_MAGIC_ext, NULL, timer, sizeof timer);
	OUTPUT:
		RETVAL

void
get_time(self)
	SV* self;
	PREINIT:
		timer_t timer;
		struct itimerspec value;
		int success;
	PPCODE:
		timer = get_timer(self, "get_time");
		success = timer_gettime(&timer, &value);
		if (success == -1) 
			die_sys("Couldn't get_time: %s");
		mXPUSHn(timespec_to_nv(&value.it_value));
		mXPUSHn(timespec_to_nv(&value.it_interval));
		XSRETURN(2);

void
set_time(self, new_value, new_interval = 0)
	SV* self;
	NV new_value;
	NV new_interval;
	PREINIT:
		timer_t timer;
		struct itimerspec new_itimer, old_itimer;
	PPCODE:
		timer = get_timer(self, "set_time");
		nv_to_itimer(new_value, &new_itimer.it_value);
		nv_to_itimer(new_interval, &new_itimer.it_interval);
		int success = timer_settime(&timer, 0, &new_itimer, &old_itimer);
		if (success == -1) 
			die_sys("Couldn't set_time: %s");
		mXPUSHn(timespec_to_nv(&old_itimer.it_value));
		mXPUSHn(timespec_to_nv(&old_itimer.it_interval));
		XSRETURN(2);

IV
get_overrun(self)
	SV* self;
	PREINIT:
		timer_t timer;
	CODE:
		timer = get_timer(self, "get_overrun");
		RETVAL = timer_getoverrun(timer);
		if (RETVAL == -1) 
			die_sys("Couldn't set_time: %s");
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
