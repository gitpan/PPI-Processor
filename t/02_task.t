#!/usr/bin/perl -w

# Formal testing for PPI::Processor::Task

# This test script only tests that the tree compiles

use strict;
use lib ();
use UNIVERSAL 'isa';
use File::Spec::Functions ':ALL';
BEGIN {
	$| = 1;
	unless ( $ENV{HARNESS_ACTIVE} ) {
		require FindBin;
		chdir ($FindBin::Bin = $FindBin::Bin); # Avoid a warning
		lib->import( catdir( updir(), updir(), 'modules') );
	}
}

use Test::More tests => 3;
use PPI::Processor       ();

# PPI::Processor::Task is actually loaded... right?
ok( $INC{"PPI/Processor/Task.pm"}, 'PPI::Processor::Task is loaded by PPI::Processor' );





# The default PPI::Process::Task class should instantiate ignoring arguments
my $PPT = 'PPI::Processor::Task';
is( $PPT->autoconstruct, 1, "$PPT supports autoconstruct" );
my $Task = $PPT->new;
isa_ok( $Task, $PPT );



exit();
