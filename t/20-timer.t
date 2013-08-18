#!perl

use strict;
use warnings;
use Test::More 0.88;

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

my $hasmodules = eval { require POSIX::RT::Signal; require Signal::Mask; POSIX::RT::Signal->VERSION(0.009) };

{
	alarm 2;
	my ($counter, $compare, $expected) = (0, 3, 3);

	my $timer = POSIX::RT::Timer->new(signal => SIGUSR1, value => 0.1, interval => 0.1, ident => 42);
	
	local $SIG{USR1} = sub {
		is ++$counter, $_, "$counter == $_";
	};

	pause for 1..3;

	alarm 0;

	SKIP: {
		skip 'POSIX::RT::Signal or Signal::Mask not installed', 3 if not $hasmodules;
		no warnings 'once';
		local $Signal::Mask{USR1} = 1;
		$expected += 3;
		for (4..6) {
			my $result = POSIX::RT::Signal::sigwaitinfo(SIGUSR1, 1);
			is($counter++, $compare++, 'Counter equals compare');
			is $result->{value}, 42, 'identifier is 42';
		}
	}

	$timer->set_timeout(0, 0);

	is($counter, $expected, 'Counter equals expected');

	local $SIG{USR1} = sub {
		fail('Shouldn\'t get a signal')
	};

	sleep .2;

	pass('Shouldn\'t get a signal');
};

done_testing;
