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
	$VERSION = '0.01';
}





#####################################################################
# Main Methods

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
	$store->{$file} ||= {};
	foreach ( $hash ) {
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

# FIXME - Do we need to do anything here?

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

L<PPI::Processor::Task>, L<PPI::Processor>, L<PPI>

=cut
