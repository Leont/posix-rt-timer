package POSIX::RT::Timer;

use 5.008;

use strict;
use warnings FATAL => 'all';

use XSLoader ();
use POSIX    ();
use Carp     ();
use Exporter 5.57 qw/import/;

our $VERSION = '0.001';
XSLoader::load(__PACKAGE__, $VERSION);

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

sub new {
	my ($class, @args) = @_;
	my %options = (
		interval => 0,
		value    => 0,
		clock    => 'monotonic',
		@args,
	);
	my @create_args = _get_args(%options);
	my $ret = $class->create($options{clock}, @create_args);
	$ret->set_time(@options{ 'value', 'interval' });
	return $ret;
}

1;    # End of POSIX::RT::Timer

__END__

=head1 NAME

POSIX::RT::Timer - The great new POSIX::RT::Timer!

=head1 VERSION

Version 0.001

=cut

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

 use POSIX::RT::Timer;

 my $timer = POSIX::RT::Timer->new(value => 1, callback => sub {
     my $timer = shift;
	 # do something
 });

=head1 METHODS

=head2 Class methods

=over 4

=item * new(%options)

Create a new timer.

=over 4

=item * value

=item * interval

=item * clock 

=item * signal

=item * callback

=back

=item * create(clock_type, response_type => $arg)

Create a new timer object.

=item * get_clocks()

Get a list of all supported clocks.

=back

=head2 Instance methods

=over 4

=item * get_time()

=item * set_time(value, interval = 0, use_abstime = 0)

=item * get_overrun()

=item * get_callback()

=item * set_callback(callback)

=back

=head1 AUTHOR

Leon Timmermans, C<< <leont at cpan.org> >>

=head1 BUGS

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
