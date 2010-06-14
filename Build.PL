use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'POSIX::RT::Timer',
    license             => 'perl',
    dist_author         => q{Leon Timmermans <leont@cpan.org>},
    dist_version_from   => 'lib/POSIX/RT/Timer.pm',
	configure_requires  => {
		'Module::Build' => 0,
	},
	build_requires      => {
		'ExtUtils::CBuilder' => 0,
		'Module::Build' => 0,
		'Test::More'    => 0,
		'Test::Exception' => 0,
	},
	requires            => {
		perl            => 5.008001,
	},
    add_to_cleanup      => [ 'POSIX-RT-Timer-*' ],
    create_makefile_pl  => 'small',
	extra_linker_flags  => [ '-lrt' ],
	sign                => 1,
);

$builder->create_build_script();
