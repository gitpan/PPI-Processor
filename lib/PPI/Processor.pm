package PPI::Processor;

=pod

=head1 NAME

PPI::Processor - Implement a PPI Document processing engine

=head1 DESCRIPTION

PPI::Processir provides a base class for implementing PPI-based Perl
Document Proccessing Engine.

This base class both provides a standard interface, and implements a
complete single-node engine.

By extending this class, it is intended to later implement a SMP,
cluster, and/or distributed parrelel processing engine as well, using
the same basic API.

=head1 METHODS

=cut

use strict;
use UNIVERSAL 'isa';
use Class::Inspector     ();
use File::Find::Rule     ();
use PPI::Document        ();
use PPI::Processor::Task ();

use vars qw{$VERSION $errstr};
BEGIN {
	$VERSION = '0.01';
	$errstr  = '';
}





#####################################################################
# Constructor

sub new {
	my $class  = ref $_[0] ? ref shift : shift;
	$class->_clear;

	# Check the source
	my %params = @_;
	unless ( $params{source} and -d $params{source} ) {
		return $class->_error("Source is not a valid directory");
	}

	# Create the basic processor object
	my $self = bless {
		source => $params{source},
		tasks  => [],
		}, $class;

	# Set the file search
	$self->{find} = isa($params{find}, 'File::Find::Rule')
		? $params{find}
		: File::Find::Rule->new
		                  ->file
		                  ->name('*.pm');

	$self;
}





#####################################################################
# Main Methods

=pod

=head2 add_task $Task

The C<add_task> method is used to add a Task to the Processor object
before processing commences.

The parameter should be either an instantiated L<PPI::Processor::Task>
object, or the same of a sub-class which is autoconstructable.

If passed a class name, the class will be loaded, the C<autoconstruct>
method will be checked, and an object will be created if the Task
class supports autoconstruct.

While adding the Task object, the Processor will also initialize the
state hash for the Task.

Returns true if the Task is added, or C<undef> on error.

=cut

sub add_task {
	my $self = shift;
	$self->_clear;
	my $Task = $self->_Task(shift) or return undef;

	# Initialise the Task's state
	### FIXME - Modifying the Task's internals directly is a little
	###         dubious. We should find a cleaner way to do this.
	$Task->{state} = {};

	# Add the Task
	push @{$self->{tasks}}, $Task;

	1;
}

=pod

=head2 run

The C<run> method starts the main processor loop. It takes no
arguments, and the function will continue to load and process
documents until it has completed all matching documents within the
document source.

Returns the total number of matching files, regardless of whether or
not they were skipped or actually processed by the various Tasks.
Returns C<undef> if a fatal processing error occured during the run.

=cut

sub run {
	my $self = shift;

	# Initialise the processing engine
	$self->init or return undef;

	# Start the main loop
	foreach my $file ( @{$self->{files}} ) {
		my $path = File::Spec->catfile( $self->{source}, $file );

		# Prepare the shared Document object if needed
		my $Document = '';
		if ( $self->{pool_documents} ) {
			$Document = PPI::Document->load($path);
		}

		# Iterate over the Tasks
		foreach my $Task ( @{$self->{tasks}} ) {
			my $rv;
			if ( $self->{pool_documents} and $Task->can('process_document') ) {
				if ( $Document ) {
					$rv = $Task->process_document($Document);
				} else {
					# Document failed to parse, skip
					$rv = '';
				}
			} else {
				# We don't need or want to use process_document
				$rv = $Task->process_file($path);
			}

			### FIXME - Add support for callbacks
		}
	}

	# End of the main loop.
	scalar @{$self->{files}};
}

=pod

=head2 init

Given the size and complexity of many document processing tasks, the
C<init> provides a convenient mechanism to prepare various things
for the main processing loop.

By default, this includes determining and storing the full list of
files to be processed, setting some state flags, and other tasks.

Returns true on success, or C<undef> on error.

=cut

sub init {
	my $self = shift;
	$self->_clear;

	# Populate the files, and return an error
	# if we don't find at least one file to process.
	my @files = $self->{find}->relative->in( $self->{source} )
		or return $self->_error("Failed to find any files to process in '$self->{source}'");
	$self->{files} = \@files;

	# Do we want to use pooled document objects?
	my $want_document = scalar grep { $_->can('process_document') } @{$self->{tasks}};
	if ( $want_document >= 2 ) {
		$self->{pool_documents} = 1;
	}

	# Set the state flag and return
	$self->{active} = 1;
}





#####################################################################
# Support and Error Handling

sub _Task {
	my $either = shift;
	my $Task   = shift;

	# Handle the easy checks first
	return $either->_error('->add_task was not passed a Task object') unless $Task;
	if ( ref $Task ) {
		return $Task if isa($Task, 'PPI::Processor::Task');
		return $either->_error('->add_task was not passed a Task object');
	}

	# So this should be the name of a PPI::Processor::Task class
	unless ( Class::Inspector->loaded($Task) ) {
		unless ( Class::Inspector->installed($Task) ) {
			return $either->_error('Not a valid Task class, or class is not installed');
		}

		# Load the class
		eval "require $Task;";
		return $either->_error("Error loading Task class '$Task': $@") if $@;
	}

	# Is the class a Task sub-class
	unless ( isa($Task, 'PPI::Processor::Task') ) {
		return $either->_error("$Task is not a PPI::Processor::Task sub-class");
	}

	# Can we auto-construct it
	unless ( $Task->autoconstruct ) {
		return $either->_error("$Task does not support auto-construct");
	}

	# Create the object
	my $Object = $Task->new;
	unless ( $Object ) {
		return $either->_error("Failed to auto-construct $Task object");
	}

	# Complete, return the object
	$Object;
}

# Set the error message
sub _error {
	$errstr = $_[1];
	undef;
}

# Clear the error message
sub _clear {
	$errstr = '';	
}

# Fetch the error message
sub errstr {
	$errstr;
}

1;

=pod

=head1 SUPPORT

Bugs should always be submitted via the CPAN bug tracker

L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=PPI%3A%3AProcessor>

For other issues, contact the maintainer

=head1 AUTHOR

Adam Kennedy (Maintainer), L<http://ali.as/>, cpan@ali.as

Funding provided by The Perl Foundation

=head1 COPYRIGHT

Copyright (c) 2004 Adam Kennedy. All rights reserved.
This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=head1 SEE ALSO

L<PPI::Processor::Task>, L<PPI>

=cut
