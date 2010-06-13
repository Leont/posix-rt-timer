package POSIX::RT::Clock;

use 5.008;

use strict;
use warnings FATAL => 'all';

our $VERSION = '0.001';

use POSIX::RT::Timer;

sub _get_args {
	my %options = @_;
	Carp::croak('no time defined') if not defined $options{value};
	if (defined $options{callback}) {
		return (callback => $options{callback});
	}
	elsif (defined $options{signal}) {
		return (signal => $options{signal});
	}
	else {
		Carp::croak('Unknown type');
	}
}

sub timer {
	my ($class, %args) = @_;
	my %options = (
		interval => 0,
		value    => 0,
		class    => 'POSIX::RT::Timer',
		%args,
	);
	my $ret = $class->_timer($options{class}, _get_args(%options));
	$ret->set_time(@options{ 'value', 'interval' });
	return $ret;
}

1;    # End of POSIX::RT::Clock

__END__

=head1 NAME

POSIX::RT::Clock - POSIX real-time clocks

=head1 VERSION

Version 0.001

=cut

=head1 SYNOPSIS

 use POSIX::RT::Timer;

 my $timer = POSIX::RT::Clock->new('monotonic');
 $timer->sleep(1);

=head1 DESCRIPTION

=head1 METHODS

=head2 Class methods

=over 4

=item * new($type)

=item * get_clocks()

Get a list of all supported clocks. These will be returned by their names, not as objects. Possible values include (but may not be limited to):

=over 4

=item * realtime 

The only timer guaranteed to always available. This is the default.

=item * monotonic

A non-settable clock guaranteed to be monotonic.

=item * process_cpu_time

A clock that measures (user and system) CPU time consumed by (all of the threads in) the calling process. This is Linux specific.

=item * thread_cpu_time

A clock that measures (user and system) CPU time consumed by the calling thread. This is Linux specific.

=back

=item * get_cpuclock($pid = 0)

Get the cpu-time clock for the process specified in $pid. If $pid is zero the current process is taken, this is the same as  

=back

=head2 Instance methods

=over 4

=item * get_time()

Get the time on this clock.

=item * set_time($time)

Set the time on this clock. Note that this may not make sense on clocks other than C<realtime>.

=item * get_resolution()

Get the resolution of this clock.

=item * sleep($time, $abstime)

Sleep a certain amount of seconds on this clock. Note that it is B<never> restarted after interruption by a signal handler. It returns the remaining time. $time and the return value are relative time unless $abstime is true.

=item * sleep_deeply($time)

Sleep a certain amount of time. Unlike C<sleep>, it will retry on interruption until the time has passed.

=item * timer(%options)

Create a timer based on this clock. All arguments except C<clock> as the same as in C<POSIX::RT::Timer::new>.

=back

=head1 AUTHOR

Leon Timmermans, C<< <leont at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-posix-rt-timer at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=POSIX-RT-Timer>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc POSIX::RT::Clock

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=POSIX-RT-Timer>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/POSIX-RT-Timer>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/POSIX-RT-Timer>

=item * Search CPAN

L<http://search.cpan.org/dist/POSIX-RT-Timer/>

=back

=head1 LICENSE AND COPYRIGHT

Copyright 2010 Leon Timmermans.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut
