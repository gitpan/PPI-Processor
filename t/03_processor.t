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

use Test::More tests => 26;
use PPI::Processor       ();

# Set the testing directory (out own modules)
my $source = 't.data';

# Create a new processor object
my $Processor = PPI::Processor->new( source => $source );
isa_ok( $Processor, 'PPI::Processor' );

# Add the null Task
my $Task = PPI::Processor::Task->new;
isa_ok( $Task, 'PPI::Processor::Task' );
is( $Processor->add_task( $Task ), 1, '->add_task( $Task ) works as expected' );
is( scalar(@{$Processor->{tasks}}), 1, '->add_task( $Task ) does add something' );
isa_ok( $Processor->{tasks}->[0], 'PPI::Processor::Task' );

# Add by class name
is( $Processor->add_task( 'PPI::Processor::Task' ), 1, '->add_task( class ) works as expected' );
is( scalar(@{$Processor->{tasks}}), 2, '->add_task( class ) does add something' );
isa_ok( $Processor->{tasks}->[1], 'PPI::Processor::Task' );

# Add our own class twice
is( $Processor->add_task( 'My::Task' ), 1, '->add_task( inline ) works as expected' );
is( scalar(@{$Processor->{tasks}}), 3, '->add_task( inline ) does add something' );
isa_ok( $Processor->{tasks}->[2], 'PPI::Processor::Task', 'My::Task' );




# Init and check it propogates correctly
is( $Processor->init, 1, '->init returns true' );
is( $Processor->{active}, 1, '->init sets the active flag' );
is( scalar(@{$Processor->{files}}), 2, '->init identifies 2 files as expected' );
ok( ! $Processor->{pool_documents}, 'pool_documents is not enabled' );



# Execute
delete $Processor->{active};
delete $Processor->{files};
delete $Processor->{pool_documents};
is( $Processor->run, 2, '->run returns the expected value' );
is( $My::Task::counter, 2, 'Test counter ends at correct value' );




# Now run again with pooling on
delete $Processor->{active};
delete $Processor->{files};
delete $Processor->{pool_documents};
is( $Processor->add_task( 'My::Task' ), 1, '->add_task( inline ) works as expected' );
is( scalar(@{$Processor->{tasks}}), 4, '->add_task( inline ) does add something' );
isa_ok( $Processor->{tasks}->[3], 'PPI::Processor::Task', 'My::Task' );

is( $Processor->init, 1, '->init returns true' );
is( $Processor->{active}, 1, '->init sets the active flag' );
is( scalar(@{$Processor->{files}}), 2, '->init identifies 2 files as expected' );
ok( $Processor->{pool_documents}, 'pool_documents is enabled' );
delete $Processor->{active};
delete $Processor->{files};
delete $Processor->{pool_documents};

is( $Processor->run, 2, '->run returns the expected value' );
is( $My::Task::counter, 6, 'Test counter ends at correct value' );

exit();




package My::Task;

use Test::More;

use strict;
use base 'PPI::Processor::Task';

use vars qw{$counter};
BEGIN {
	$counter = 0;
}

sub process_document {
	$My::Task::counter++;
}

1;
