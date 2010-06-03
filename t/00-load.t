#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'POSIX::RT::Timer' ) || print "Bail out!
";
}

diag( "Testing POSIX::RT::Timer $POSIX::RT::Timer::VERSION, Perl $], $^X" );
