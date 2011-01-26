use 5.008001;
use strict;
use warnings;
use Module::Build;

if ($^O eq 'MSWin32') {
  print STDERR "OS not supported\n";
  exit 0;
}

my $builder = Module::Build->new(
  module_name         => 'POSIX::RT::Timer',
##{ $plugin->get_prereqs ##}
  extra_linker_flags  => [ '-lrt' ],
);

$builder->create_build_script();
