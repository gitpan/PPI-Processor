package PPI::Processor::Task;

=pod

=head1 NAME

PPI::Processor::Task - Abstract base class for a single task in a Processor

=head1 DESCRIPTION

This class describes and implements the basic Task API, which can be
inherited from by any class in order to be used within a PPI::Processor
instance.

=head1 METHODS

=cut

use strict;
use UNIVERSAL 'isa';
use PPI::Document ();

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.06';
}





#####################################################################
# Constructor

=pod

=head2 new ...

The C<new> constructor is used to create new Task objects to be passed to
a Processor for execution.

Although any number of parameters may be required to be passed to the Task
constructor, by default C<new> is implemented for you as an empty
constructor that creates an empty (although valid) object.

Returns a new PPI::Processor::Task object, or C<undef> on error.

=cut

sub new {
	my $class = ref $_[0] ? ref shift : shift;

	# Create the object
	my $self  = bless {
		}, $class;

	$self;
}

=pod

=head2 autoconstruct

Many simple Tasks do not require any constructor arguments, and can be
simply created as-needed by the processor.

If the static method autoconstruct returns true, the Processor will
auto-construct the task object as needed.

Returns true by default. You will need to disable autoconstruct when
creating Tasks that need constructor arguments, using the following.

  # Disable auto-construct
  sub autoconstruct { '' }

=cut

sub autoconstruct { 1 }






#####################################################################
# PPI::Processor::Task Main Methods

=pod

=head2 store

All Tasks need something in which to store their results. The actual
location of where it is stored will vary depending on the
implementation of the particular Task.

The C<store> method is used to access the data store for each Task,
returning a reference to it which you may modify directly.

In the simplest case, returns a reference to a HASH. More complex
Tasks may use a tied object or a database connector or some other
mechanism.

=cut

sub store {
	my $self = shift;

	# Handle the most common cases
	exists $self->{store}
		? $self->{store}
		: die "Unable to locate the Task's result store";
}

=pod

=head2 init_store

Before a processing run can commence, each Task has the opportunity
to initialise their result stores. The C<init_store> 

Returns true if the result store is initialised or connected to, or
false otherwise.

=cut

sub init_store {
	my $self = shift;
	$self->{store} = {};
	1;	
}

=pod

=head2 flush_store

Some Tasks, particularly database-backed parellel-capable ones,
store their state outside the context of a single run of a Processor.

In these cases, the C<flush_store> method is intented to clear away
any and all previous result data and reset the result store for use.

This method is called, if needed, AFTER the C<init_store> method.

Returns true if the result store is flushed, or false otherwise.

=cut

sub flush_store {
	my $self = shift;
	return undef unless $self->{store};
	%{$self->{store}} = ();
	1;
}

=pod

=head2 end_store

The C<end_store> method completements the C<init_store> method, and 
is used to clean up, disconnect, save, or otherwise "finish" the use
of the store at the end of a run.

Returns true if the store is finished successfully, or false otherwise.

=cut

# Do nothing in the default case.
# Since we don't save our hash, we don't want to just throw all that
# data away at the end of a run.
sub end_store {
	my $self = shift;
	1;
}

=pod

=head2 process_file $filename

The C<process_file> method is the lowest level processing method used to
do the processing of the perl documents.

It is passed the fully-resolved file name for the file that is to be
loaded and processed.

Because the Task starts with the filename only, it is free to destroy or
manipulate the Document in any way it likes, or even skip processing of
the file based on it's name.

The default implementation is to load the file and pass it to the
C<process_document> method (if it exists), or to return false (skips the
file) if there is no C<process_document> method.

Because the default implementation is designed to support Tasks that
only handle full Documents and don't care about broken documents, the
method will return false (skipping the file) if the Document load
process fails.

Returns true if the file is processed successfully, false if skipped, or
C<undef> if an error occurred while processing the file.

=cut

sub process_file {
	my $self = shift;
	my $file = shift;

	# Skip if no process_document method
	return '' unless $self->can('process_document');

	# Load the Document or skip on failure
	my $Document = PPI::Document->load($file) or return '';

	# Hand off to the next method
	$self->process_document( $Document, $file );
}

=pod

=head2 process_document $Document, $file

The C<process_document> method should be implemented by Tasks that wish
to work only with fully parsed documents, and are not concerned about
documents that fail to load.

In order to improve the speed of the Processor, any Task that uses
process_document must also guarentee that it will not modify the
Document object passed to it (although it may clone it and subsequently
modify THAT version).

This is because in some situations the Processor may cache the Document
object and pass it to each of several different Tasks for processing.

This method is not implemented in the default class.

Returns true if the Document object was processed, false if skipped,
or C<undef> on error.

=cut

# sub process_document { '' }

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

Copyright (c) 2004 - 2005 Adam Kennedy. All rights reserved.
This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=head1 SEE ALSO

L<PPI::Processor>, L<PPI>

=cut
