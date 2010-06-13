#!perl -T

use strict;
use warnings;
use Test::More tests => 4;

use Time::HiRes qw/alarm sleep/;
use POSIX::RT::Timer;
use POSIX qw/SIGUSR1 pause/;

{
	alarm 0.2;

	local $SIG{USR1} = sub {
		pass('Got signal');
	};

	my $timer = POSIX::RT::Timer->new(signal => SIGUSR1, value => 0.1);

	pause;

	alarm 0;
}

{
	alarm 0.2;

	local $SIG{USR1} = sub {
		pass('Got signal');
	};

	my $timer = POSIX::RT::Timer->new(clock => 'realtime', signal => SIGUSR1, value => 0.1);

	pause;

	alarm 0;
}

{
	alarm 2;
	my $num = 10;
	my $counter;
	local $SIG{USR1} = sub {
		$counter++;
	};
	my $timer = POSIX::RT::Timer->new(signal => SIGUSR1, value => 0.1, interval => 0.1);

	pause while $num--;
	is ($counter, 10);

	alarm 0;

	$timer->set_time(0, 0);

	local $SIG{USR1} = sub {
		fail('Shouldn\'t get a signal')
	};

	sleep .2;

	pass('Shouldn\'t get a signal');
}
