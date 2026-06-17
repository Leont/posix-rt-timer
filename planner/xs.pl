#! perl

use strict;
use warnings;

load_extension('Dist::Build::XS');
load_extension('Dist::Build::XS::Conf');

find_libraries_for(source => <<EOF, libs => [ [], [ 'rt' ] ]);
#include <stdlib.h>
#include <time.h>

int main(int argc, const char** argv) {
	struct timespec time = { 0, 0 };
	clock_gettime(CLOCK_REALTIME, &time);
	return 0;
}

EOF

add_xs();
