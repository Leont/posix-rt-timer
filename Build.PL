use 5.008001;
use strict;
use warnings;
use Devel::CheckLib;
use Module::Build;

my @extra_linker_flags = map { "-l$_" } grep { check_lib(lib => $_) } qw/rt/;

if ($^O eq 'MSWin32') {
  print STDERR "OS not supported\n";
  exit 0;
}

my $builder = Module::Build->new(
  module_name         => 'POSIX::RT::Timer',
##{ $plugin->get_prereqs ##}
  extra_linker_flags  => \@extra_linker_flags,
);

$builder->create_build_script();
