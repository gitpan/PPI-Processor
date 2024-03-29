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

=head1 EXTENDING

At this time the API is still drifting a little bit.

If you wish to write Tasks or extensions, please stay in touch with the
maintainer while doing so.

=head1 METHODS

=cut

use strict;
use UNIVERSAL 'isa';
use Class::Inspector     ();
use File::Find::Rule     ();
use PPI::Document        ();

use vars qw{$VERSION $errstr};
BEGIN {
	$VERSION = '0.15';
	$errstr  = '';
}





#####################################################################
# Constructor and Accessors

=pod

=head2 new %args

The C<new> constructor creates a new Processor object. It takes as argument
a set of name => value pairs. The base class accepts two named parameters.

=over

=item source

The required C<source> param identifies the source directory for the perl
files to be processed. It must be a directory that exists and for which we
have read permissions.

=item find

The optional C<find> parameter lets you pass a L<File::Find::Rule> object
that will be used to find the set of files within the source directory
that are to be processed.

If not provided, a default File::Find::Rule object will be used that
processes all .pm files contained in the source directory.

=item trace

The C<trace> option (disabled by default) causes trace/debugging messages to
be printed to STDOUT as the processing run processes.

=item trace_summary

For large and very long running processes, enabling the C<trace_summary>
option (disabled by default) will cause an addition job summary to be
printed at roughly minute interval summarising the current status of the
processing job.

=item flush_results

Some Task classes (generally the parellel-capable ones that generate
information on a per-file basis) support incremental state.

That is, they are able to determine if they have previously calculated
a result for a file, and skip it.

Setting flush_results to true (false by default) will force any of these
shared states to be reset before the processing run starts.

=item limit

The C<limit> option is an integer value indicating the maximum
number of files to be processed in a single process (mainly to mitigate
any potential leaks in PPI).

If set to default, will parse any number.

=back

Returns a new PPI::Processor object, or C<undef> on error.

=cut

sub new {
	my $class  = ref $_[0] ? ref shift : shift;
	$class->_clear;

	# Check the source
	my %args = @_;
	unless ( $args{source} and -d $args{source} ) {
		return $class->_error("Source is not a valid directory");
	}

	# Create the basic processor object
	my $self = bless {
		source        => $args{source},
		tasks         => [],
		}, $class;

	# Handle optional parameters
	$self->{trace}         = 1 if $args{trace};
	$self->{trace_summary} = 1 if $args{trace_summary};
	$self->{flush_results} = 1 if $args{flush_results};
	delete $self->{trace_summary} unless $self->{trace};

	# Support limits
	if ( defined $args{limit} and $args{limit} > 0 ) {
		$self->{limit} = $args{limit};
	}

	# Set the file search
	$self->{find} = isa($args{find}, 'File::Find::Rule')
		? $args{find}
		: File::Find::Rule->new
		                  ->file
		                  ->name('*.pm');

	$self;
}

=pod

=head2 source

The C<source> accessor method returns the source directory that the
object was created with.

=cut

sub source { $_[0]->{source} }





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
store for the Task.

Returns true if the Task is added, or C<undef> on error.

=cut

sub add_task {
	my $self = shift->_clear;
	my $Task = $self->_Task(@_) or return undef;

	# Initialise the store
	$Task->init_store or return undef;

	# Flush the store if flush_results is enabled
	if ( $self->{flush_results} ) {
		$Task->flush_store or return undef;
	}

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
	local $| = 1;

	# Initialise the processing engine
	$self->init or return undef;

	# Start the main loop
	my $completed = -1;
	$self->trace("Running processor job for " . scalar(@{$self->{files}}) . " files...\n");
	foreach my $path ( @{$self->{files}} ) {
		# Show the process summary if needed
		$self->_trace_summary( ++$completed );
		$self->trace("Processing $path");

		# Get the full path to the file
		my $file = File::Spec->catfile( $self->{source}, $path );

		# Prepare the shared Document object if needed
		my $Document = '';
		if ( $self->{pool_documents} ) {
			$Document = PPI::Document->new($file);
			unless ( $Document ) {
				$self->trace(' error\n');
				next;
			}
		}
	
		# Iterate over the Tasks
		foreach my $Task ( @{$self->{tasks}} ) {
			$self->trace('... ');
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
				$rv = $Task->process_file($file, $path);
			}

			# Show the results
			$self->trace($rv ? 'done' : defined($rv) ? 'skipped' : 'error');
		}

		$self->trace("\n");
	}

	# End of the main loop.
	$self->trace("Processor job complete\n");
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
	my $self = shift->_clear;

	# Populate the files, and return an error
	# if we don't find at least one file to process.
	$self->trace("Search for files...");
	my @files = $self->{find}->relative->in( $self->{source} )
		or return $self->_error("Failed to find any files to process in '$self->{source}'");
	$self->trace(" found " . scalar(@files) . " files\n");
	@files = sort @files;

	# Support the limit option
	if ( $self->{limit} and $self->{limit} > 0 ) {
		# Only needed if the source set is too large
		if ( @files > $self->{limit} ) {
			$self->trace("Limiting to first $self->{limit} only (limit enabled)\n");
			$self->trace("Ending at $files[$self->{limit}]\n");
			@files = @files[1 .. $self->{limit}];
		}
	}

	# Do we want to use pooled document objects?
	my $want_document = scalar grep { $_->can('process_document') } @{$self->{tasks}};
	$self->{pool_documents} = 1 if $want_document >= 2;

	# Initialize the trace summary if needed
	if ( $self->{trace_summary}  ) {
		$self->{trace_summary_start} = $self->{trace_summary_last} = time;
	}

	# Clean up and return true
	$self->{files} = \@files;
	$self->{active} = 1;
}





#####################################################################
# Support and Error Handling

=pod

=head2 trace $message

Prints out a trace/debug message, if they are enabled

=cut

sub trace {
	my ($self, $message) = @_;
	print "$message" if $self->{trace};
}

# Generate the per-minute summary if needed
sub _trace_summary {
	my ($self, $completed) = @_;
	return 1 unless $self->{trace_summary};

	# Do we need to show a summary yet?
	my $now      = time;
	my $interval = $now - $self->{trace_summary_last};
	return 1 if $interval < 60;

	# Calculate some additional values
	my $files     = scalar @{$self->{files}};
	my $expired   = $now - $self->{trace_summary_start};
	my $remaining = int($expired * ($files - $completed) / $completed);
	my $hours   = int($remaining / 3600);
	my $minutes = int(($remaining % 3600) / 60);
	my $seconds = $remaining % 60;
	my $eta     = $hours ? sprintf("%dh %02dm %02ds", $hours, $minutes, $seconds)
		: $minutes ? sprintf("%dm %02ds", $minutes, $seconds)
		: sprintf("%ds", $seconds);

	# Generate and show the summary
	$self->trace("\n");
	$self->trace("Job Status Update: Completed $completed of $files - ETA $eta\n");
	$self->trace("\n");

	# Update the last time
	$self->{trace_summary_last} = $now;
}

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
	$Task->new( @_ ) or $either->_error("Failed to auto-construct $Task object");
}

# Set the error message
sub _error {
	$errstr = $_[1];
	undef;
}

# Clear the error message.
# Returns the object as a convenience.
sub _clear {
	$errstr = '';
	$_[0];
}

=pod

=head2 errstr

For any error that occurs, you can use the C<errstr>, as either
a static or object method, to access the error message.

If no error occurs for any particular action, C<errstr> will return false.

=cut

sub errstr {
	$errstr;
}

1;

=pod

=head1 SUPPORT

Bugs should always be submitted via the CPAN bug tracker

L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=PPI-Processor>

For other issues, contact the maintainer

=head1 AUTHOR

Adam Kennedy (Maintainer), L<http://ali.as/>, cpan@ali.as

Funding provided by The Perl Foundation

=head1 COPYRIGHT

Copyright (c) 2004 - 2005 Adam Kennedy. All rights reserved.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=head1 SEE ALSO

L<PPI::Processor::Task>, L<PPI>

=cut
