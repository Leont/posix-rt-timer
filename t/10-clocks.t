#!perl -T

use strict;
use warnings;
use Test::More;
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

note("Supported clocks are: ". join ', ', keys %clocks) if not $ENV{AUTOMATED_TESTING};

is delete $clocks{realtime}, 1, 'Realtime clock is supported';

for my $clock_name (keys %clocks) {
	my $new_clock = POSIX::RT::Clock->new($clock_name);
	ok($new_clock->get_time(), "Clock '$clock_name' seems to work");
}

ok $clock->get_resolution, 'Can get resolution';

SKIP: {
	skip 'Has cpuclock', 1 if $^O ne 'linux';

	my $other;
	lives_ok { $other = POSIX::RT::Clock->get_cpuclock } 'Has cpuclock';
}

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

done_testing(14 + scalar keys %clocks);
