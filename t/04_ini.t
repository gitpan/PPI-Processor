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

use Test::More tests => 24;
use PPI::Processor::KeyedTask::Ini ();
use Config::Tiny ();
use PPI::Document ();

my $PPI  = 'PPI::Processor::KeyedTask::Ini';
my $file = File::Spec->catfile( 't.data', 'test.ini' );





# Create and init the task class
my $Task = PPI::Processor::KeyedTask::Ini->new(
	tasks => {
		foo => sub { 1 },
		bar => sub { 2 },
		},
	file  => $file,
	);
isa_ok( $Task, 'PPI::Processor::Task'                 );
isa_ok( $Task, 'PPI::Processor::KeyedTask'      );
isa_ok( $Task, 'PPI::Processor::KeyedTask::Ini' );
is( $Task->{file}, $file, '->{file} matches expected value' );
ok( ref $Task->{tasks} eq 'HASH', 'The tasks hash exists' );

# Try to init the task
ok( $Task->init_store, '->init_store returns true' );
isa_ok( $Task->store, 'Config::Tiny' );
is( $Task->store->{foo}->{bar}, 'baz', 'Can read the contents of the store ok' );

# Try to flush it
ok( $Task->flush_store, '->flush_store returns true' );
isa_ok( $Task->store, 'Config::Tiny' );
is( scalar(keys %{$Task->store}), 0, 'Store is empty' );

# Add something
ok( $Task->store_file( 'foo', { this => 'that', one => 'two' } ), '->store_file returns true' );
isa_ok( $Task->store, 'Config::Tiny' );
is( $Task->store->{foo}->{this},    'that', '->store_file stored value correctly' );
is( $Task->store->{foo}->{one}, 'two',  '->store_file stored value correctly' );

# Now give it a (wrong) Document to process
my $Document = PPI::Document->new();
ok( $Task->process_document( $Document, 'file', 'file' ), '->process_document returns true' );
is( $Task->store->{file}->{foo}, 1, '->process_document saves value correctly' );
is( $Task->store->{file}->{bar}, 2, '->process_document saves value correctly' );

# End the store
ok( $Task->end_store, '->end_store returned true' );

# Manually load the file and see if it changed
my $Config = Config::Tiny->read( $file );
isa_ok( $Config, 'Config::Tiny' );
is( $Config->{foo}->{this}, 'that', '->end_store wrote data to disk' );
is( $Config->{foo}->{one},  'two',  '->end_store wrote data to disk' );
is( $Config->{file}->{foo}, 1,      '->end_store wrote data to disk' );
is( $Config->{file}->{bar}, 2,      '->end_store wrote data to disk' );

# Restore the test config file
END {
	if ( $Config ) {
		$Config->{foo} = { bar => 'baz' };
		$Config->write( $file );
	}
}





exit();
