#!perl -T

use strict;
use warnings;
use Test::More tests => 15;
use Test::Exception;

use POSIX::RT::Clock;
use Time::HiRes 'alarm';

alarm 5;

my $clock;
lives_ok { $clock = POSIX::RT::Clock->new('realtime') } 'Can be created';

my $time = $clock->get_time();

ok $time, 'gettime works';

ok $clock + 0, 'Can be used as a number';

my %clocks = map { ( $_ => 1 ) } POSIX::RT::Clock->get_clocks;

ok scalar(keys %clocks), 'Has clocks';

note("Supported clocks are: ". join ', ', keys %clocks);

is $clocks{realtime}, 1, 'Realtime clock is supported';

ok $clock->get_resolution, 'Can get resolution';

SKIP: {
	skip 'No monotonic clock', 1 if not $clocks{monotonic};
	my $new_clock = POSIX::RT::Clock->new('monotonic');
	lives_ok { $new_clock->get_time() } "Monotonic clock seems to work";
}

SKIP: {
	skip 'Doesn\'t have cpuclock', 1 if POSIX::RT::Clock->can('get_cpuclock');
	lives_ok { POSIX::RT::Clock->get_cpuclock } 'Has cpuclock';
}

SKIP: {
	skip 'Can\'t sleep, poor bastard', 6 if not $clock->can('sleep');

	my $slept = $clock->sleep(0.5);
	is($slept, 0, 'Slept all the time');

	cmp_ok($clock->get_time, '>', $time + 0.5, '0.5 seconds expired');

	is($clock->sleep($clock->get_time() + 0.5, 1), 0, 'Absolute sleep worked too');

	$time = $clock->get_time;
	local $SIG{ALRM} = sub { cmp_ok($clock->get_time, '>', $time + 0.2, 'sighandler called during sleep_deeply')};
	alarm 0.2;
	cmp_ok($clock->sleep(0.5), '>', 0.2, 'Sleeper interrupted');

	alarm 0.2;
	is($clock->sleep_deeply(0.5), 0, 'Deep sleeper continued');
}

