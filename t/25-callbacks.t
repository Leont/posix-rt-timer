#!perl

use strict;
use warnings;
use Test::More tests => 3;

use Time::HiRes qw/alarm sleep/;
use POSIX::RT::Timer;
use POSIX qw/pause/;

{
	my $timer = POSIX::RT::Timer->new(value => 0.1, callback => sub { pass('Got signal'); });

	alarm 0.2;

	pause;
}

{
	alarm 2;

	my $counter;
	my $num = 10;
	my $timer = POSIX::RT::Timer->new(value => 0.1, interval => 0.1, callback => sub {
		$counter++;
	});
	pause while $num--;
	is ($counter, 10);

	alarm 0;

	$timer->set_timeout(0, 0);

	my $fail = 0;
	$timer->set_callback(sub {
		$fail++;
	});

	sleep .2;

	is($fail, 0, 'Shouldn\'t get a signal');
}
