package PPI::Processor::KeyedTask;

=pod

=head1 NAME

PPI::Processor::KeyedTask - A Task class that generates simple
per-file results

=head1 DESCRIPTION

Many types of Tasks generate relatively simple data on a per-file basis.

The KeyedTask class is simply the creation of these types of tasks, with
the data most often written into a database or other external storage of
some sort.

=head2 Expanded API

KeyedTask classes attempt to take care of most of the "hard" work of
being a Task class, and allow you to create basic Task objects for which
the data can be processed later.

Each Task object has, or is configured with, a number of named tests.
Each of these tests is passed the Document object for the file, and should
return a normal value, or something that stringifies to one.

Once all tests have been run, a hash of the results is created and passed
to the C<store_file_hash> with the name of the file being processed, with the
actual data formatting and storage taken care of by the KeyedTask class.

=head1 METHODS

=cut

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Processor::Task';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.11';
}

# Requires arguments, and therefore cannot autoconstruct
sub autoconstruct { 0 }





#####################################################################
# Constructor

=pod

=head2 new %args

The C<new> constructor takes a set of paired arguments and largely
passes them on to the default L<PPI::Processor::Task> constructor.

It accepts one additional argument other than the default

=over

=item tasks

The C<tasks> argument should be a hash of named subtask. Each key should
be a simple word, and each value can be one of three things.

  'Module::Name::function'

A string in this format will cause the task to be done by calling the named
function, passing it the L<PPI::Document> object as the first argument, and
filename as second argument.

  'Module::Name->method'

A string in this form will cause the task to be done by calling the named
static method, passing it the L<PPI::Document> object as the first
argument, and filename as second argument. Please note that the string is
not evaluated, the notation is merely used to indicate that it is a method.

  &coderef

Any anonymous subroutine reference provided as a task will be called
directly, and is passed the L<PPI::Document> object as the first argument,
and filename as second argument.

=back

Returns a new PPI::Processor::KeyedTask object, or C<undef> on error.

=cut

sub new {
	my $class = ref $_[0] ? ref shift : shift;
	my %args  = @_;

	# Check the tasks
	my $tasks = delete $args{tasks};
	if ( $tasks ) {
		return undef unless ref $tasks eq 'HASH';
		foreach ( keys %$tasks ) {
			$tasks->{$_} = $class->_compile_task($tasks->{$_}) or return undef;
		}
	}

	# Create the object
	my $self = $class->SUPER::new( %args ) or return undef;

	# Add the tasks
	$self->{tasks} = $tasks if $tasks;

	$self;
}





#####################################################################
# Main Methods

=pod

=head2 tasks

The C<tasks> method returns a hash of the named tasks that need to be
performed by the Task object. The list are to be performed in alpha-sorted
order. As for unit test scripts, if the order is important they should be
named 01task, 02task, 03task, etc etc.

Returns a hash as a list, or the null list if no tasks can be determined.

=cut

sub tasks {
	my $self = shift;
	return () unless $self->{tasks};
	map { $_ => $self->{tasks}->{$_} } sort keys %{$self->{tasks}};
}

=pod

=head2 store_file $file, $hash

The C<store_file> method stores a set of keyed values against a filename.

It takes as argument the name of the file being processed, and a HASH
reference.

Returns true if the values are stored, or false otherwise.

=cut

sub store_file {
	my ($self, $file, $hash) = @_;
	return undef unless ref $hash eq 'HASH';

	# Add the hash entries to the result store entry for that file
	my $store = $self->store;
	$store->{$file} = {} unless $store->{$file};
	foreach ( keys %$hash ) {
		$store->{$file}->{$_} = $hash->{$_};
	}

	1;
}

=pod

=head2 flush_file $file

The C<flush_file> method takes a file name, and removes any and all
entries for it in the result store.

Returns true on success, or false otherwise.

=cut

sub flush_file {
	my ($self, $file) = @_;

	# Remove the entry from the store
	my $store = $self->store;
	delete $store->{$file};

	1;
}





#####################################################################
# PPI::Processor::Task Methods

=pod

=head2 process_document $Document, $file

Instead of doing a single task on the Document, the KeyedTask
sub-class is designed to run a number of analysis tasks at one time.

The process_document method provides the default mechanism by
loading and calling the methods indicated by the C<tasks> method.

This class assumes that all the tasks can be achieved using a Document
in a non-destructive way. If there is any chance the parsing might fail
during the process, you should use C<process_file> manually.

The use of a manual C<process_file> method in a ::KeyedTask sub-class
will cause it to be used instead of this C<process_document> and
C<tasks> mechanism.

=cut

sub process_document {
	my $self     = shift;
	my $Document = isa($_[0], 'PPI::Document') ? shift : return undef;
	my $filename = shift;

	# Hand off to each of the tasks
	my %tasks   = $self->tasks or return undef;
	my %results = map { $_ => undef } keys %tasks;
	foreach my $task ( sort keys %tasks ) {
		eval {
			local $_ = $filename;
			$results{$task} = $tasks{$task}->($Document, $filename);
		};
		last if $@; # Skip the rest of the tests on error
	}

	# Save the results
	$self->store_file( $filename, \%results );
}





#####################################################################
# Support Methods

sub _compile_task {
	my $either = shift;
	my $task   = defined $_[0] ? shift : return undef;
	return $task if ref $task eq 'CODE';
	return undef if ref $task;
	return undef unless $task =~ /^([^\W\d]\w*(?:::[^\W\d]\w*)*)(?:::|->)[^\W\d]\w*$/;
	my $rv = eval "sub { require $1; return $task( \$_ ); }";
	$@ ? undef : $rv;
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

Copyright (c) 2004 - 2005 Adam Kennedy. All rights reserved.
This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=head1 SEE ALSO

L<PPI::Processor::Task>, L<PPI::Processor>, L<PPI>

=cut
