package POSIX::RT::Timer;

use 5.008001;

use strict;
use warnings FATAL => 'all';

use XSLoader ();
use POSIX    ();

our $VERSION = '0.008';
XSLoader::load(__PACKAGE__, $VERSION);

use POSIX::RT::Clock;

sub new {
	my ($class, %options) = @_;
	my $clock = POSIX::RT::Clock->new(delete $options{clock} || 'realtime');
	return $clock->timer(%options, class => $class);
}

1;    # End of POSIX::RT::Timer

__END__

=head1 NAME

POSIX::RT::Timer - POSIX real-time timers

=head1 VERSION

Version 0.008

=cut

=head1 SYNOPSIS

 use POSIX::RT::Timer;

 my $timer = POSIX::RT::Timer->new(value => 1, callback => sub {
     my $timer = shift;
	 # do something
 });

=head1 DESCRIPTION

This module provides for timers. Unlike getitimer/setitimer an arbitrary number of timers is supported. There are two kinds of timers: signal timers and callback timers.

Signal timers send a signal to the process, much like itimers. You can specify which signal is sent, using realtime signals is recommended.

Callback timers call a callback on expiration. They are actually implemented by a signal handler on C<$POSIX::RT::Timer::SIGNO>. The value of this variable can be set B<before> loading this module. Callbacks are called with the timer as their only argument.

=head1 METHODS

=head2 Class methods

=over 4

=item * new(%options)

Create a new timer. Options include

=over 4

=item * value = 0

The time in factional seconds for timer expiration. If it is 0 the timer is disarmed.

=item * interval = 0

The value the timer is set to after expiration. If this is set to 0, it is a one-shot timer.

=item * clock = 'realtime'

The type of clock

=item * signal

The signal number to send a signal to on timer expiration.

=item * callback

The callback to call on timer expiration. The callback will receive the timer as its only arguments.

=back

Signal and callback options are mutually exclusive. It is mandatory to set one of these. Signal timers can not be converted into callback timers or reverse.

=item * get_clocks()

Get a list of all supported clocks by their names.

=back

=head2 Instance methods

=over 4

=item * get_timeout()

Get the timeout value. In list context, it also returns the interval value. Note that this value is always relative to the current time.

=item * set_timeout($value, $interval = 0, $abstime = 0)

Set the timer and interval values. If C<$abstime> is true, they are absolute values, otherwise they are relative to the current time. Returns the old value like C<get_time> does.

=item * get_overrun()

Get the overrun count for the timer. The timer overrun count is the number of additional timer expirations that occurred since the signal was sent.

=item * get_callback()

Get the callback function.

=item * set_callback($callback)

Set the callback function.

=back

=head1 AUTHOR

Leon Timmermans, C<< <leont at cpan.org> >>

=head1 BUGS

Perl can interact weirdly with signals. Beware of the dragons.

POSIX::RT::Timer currently uses an unsafe signal handler for callback handlers.

Please report any bugs or feature requests to C<bug-posix-rt-timer at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=POSIX-RT-Timer>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc POSIX::RT::Timer

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
