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

use Test::More tests => 11;
use PPI::Processor            ();
use PPI::Processor::Task      ();
use PPI::Processor::KeyedTask ();

my $PPT = 'PPI::Processor::Task';
my $PPK = 'PPI::Processor::KeyedTask';





# The default PPI::Process::Task class should instantiate ignoring arguments
{
is( $PPT->autoconstruct, 1, "$PPT supports autoconstruct" );
my $Task = $PPT->new;
isa_ok( $Task, $PPT );
is( $Task->flush_store, undef, '->flush_store returns false before init' );
ok( $Task->init_store, '->init_store retrurns true' );
ok( $Task->flush_store, '->flush_store returns true after init' );
}




# So should the default KeyedTask
{
is( $PPK->autoconstruct, 0, "$PPT supports autoconstruct" );
my $Task = $PPK->new;
isa_ok( $Task, $PPK );
isa_ok( $Task, $PPT );
is( $Task->flush_store, undef, '->flush_store returns false before init' );
ok( $Task->init_store, '->init_store retrurns true' );
ok( $Task->flush_store, '->flush_store returns true after init' );
}




exit();
