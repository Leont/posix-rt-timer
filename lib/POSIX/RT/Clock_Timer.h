/*
 * Shared header of POSIX::RT::Clock and POSIX::RT::Timer
 */

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
	{ "realtime" , CLOCK_REALTIME  }
#ifdef CLOCK_MONOTONIC
	, { "monotonic", CLOCK_MONOTONIC }
#elif defined CLOCK_HIGHRES
	, { "monotonic", CLOCK_HIGHRES }
#endif
#ifdef CLOCK_PROCESS_CPUTIME_ID
	, { "process", CLOCK_PROCESS_CPUTIME_ID }
#elif defined CLOCK_PROF
	, { "process", CLOCK_PROF }
#endif
#ifdef CLOCK_THREAD_CPUTIME_ID
	, { "thread", CLOCK_THREAD_CPUTIME_ID }
#endif
#ifdef CLOCK_UPTIME
	, { "uptime", CLOCK_UPTIME }
#endif
#ifdef CLOCK_VIRTUAL
	, { "virtual", CLOCK_VIRTUAL }
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

#define NANO_SECONDS 1000000000

static NV timespec_to_nv(struct timespec* time) {
	return time->tv_sec + time->tv_nsec / (double)NANO_SECONDS;
}

static void nv_to_timespec(NV input, struct timespec* output) {
	output->tv_sec  = (time_t) floor(input);
	output->tv_nsec = (long) ((input - output->tv_sec) * NANO_SECONDS);
}

