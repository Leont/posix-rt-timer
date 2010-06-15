package POSIX::RT::Clock;

use 5.008;

use strict;
use warnings FATAL => 'all';
use Carp ();

our $VERSION = '0.004';

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
	$ret->set_timeout(@options{ 'value', 'interval' });
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

POSIX::RT::Clock offers access to various clocks, both portable and OS dependent.

=head1 METHODS

=head2 Class methods

=over 4

=item * new($type)

Create a new clock. The C<$type>s supported are documented in C<get_clocks>.

=item * get_clocks()

Get a list of all supported clocks. These will be returned by their names, not as objects. Possible values include (but may not be limited to):

=over 4

=item * realtime 

The same clock as C<time> and L<Time::HiRes> use. It is the only timer guaranteed to always available and is therefor the default.

=item * monotonic

A non-settable clock guaranteed to be monotonic. This is defined in POSIX and supported on most operating systems.

=item * process

A clock that measures (user and system) CPU time consumed by (all of the threads in) the calling process. This is supported on many operating systems.

=item * thread

A clock that measures (user and system) CPU time consumed by the calling thread. This is Linux specific.

=item * uptime

A clock that measures the uptime of the system. This is FreeBSD specific.

=item * virtual

A clock that counts time the process spent in userspace. This is supported only in FreeBSD, NetBSD and Solaris.

=back

=item * get_cpuclock($pid = 0)

Get the cpu-time clock for the process specified in $pid. If $pid is zero the current process is taken, this is the same as the C<process> clock. This call is currently not supported on most operating systems, despite being defined in POSIX.

=back

=head2 Instance methods

=over 4

=item * get_time()

Get the time of this clock.

=item * set_time($time)

Set the time of this clock. Note that this may not make sense on clocks other than C<realtime> and will require sysadmin permissions.

=item * get_resolution()

Get the resolution of this clock.

=item * sleep($time, $abstime = 0)

Sleep a C<$time> seconds on this clock. Note that it is B<never> restarted after interruption by a signal handler. It returns the remaining time. $time and the return value are relative time unless C<$abstime> is true.

=item * sleep_deeply($time, $abstime = 0)

Sleep a C<$time> seconds on this clock. Unlike C<sleep>, it will retry on interruption until the time has passed.

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
