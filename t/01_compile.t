#!/usr/bin/perl -w

# Formal testing for PPI::Processor

# This test script only tests that the tree compiles

use strict;
use lib ();
use UNIVERSAL 'isa';
use File::Spec::Functions ':ALL';
BEGIN {
	$| = 1;
	unless ( $ENV{HARNESS_ACTIVE} ) {
		require FindBin;
		$FindBin::Bin = $FindBin::Bin; # Avoid a warning
		chdir catdir( $FindBin::Bin, updir() );
		lib->import('blib', 'lib');
	}
}

use Test::More tests => 5;





# Check their perl version
ok( $] >= 5.005, "Your perl is new enough" );

# Does the module load
use_ok( 'PPI::Processor'                 );
use_ok( 'PPI::Processor::Task'           );
use_ok( 'PPI::Processor::KeyedTask'      );
use_ok( 'PPI::Processor::KeyedTask::Ini' );

exit();
