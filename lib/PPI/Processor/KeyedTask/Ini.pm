package PPI::Processor::KeyedTask::Ini;

=pod

=head1 NAME

PPI::Processor::KeyedTask::Ini - Sample KeyedTask storage driver based on
Config::Tiny

=head1 DESCRIPTION

L<PPI::Processor::KeyedTask> generates file-keyed results. The overall
structure tends to become a hash of hashes. L<Config::Tiny> lets you work
with .ini-style files easily using a hash of hashes. You see where I'm
going here?

PPI::Processor::KeyedTask::Ini is a sample storage driver for
PPI::Processor::KeyedTask that writes the result data out to a .ini-style
file in the format.

  [authors/id/A/AD/ADAMK/Config-Tiny-2.00.tar.gz/Config-Tiny-2.00/lib/Config/Tiny.pm]
  tokenized     = 1
  lexed         = 1
  balanced_tree = 0

That is, one section for each file with the test keys as properties.

It provides a simple output format when developing new Task classes and
objects, which can be later moved to something larger like a SQLite
backend.

=head1 METHODS

This class has no additional method beyond the base
L<PPI::Processor::KeyedTask> interface.

=cut

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Processor::KeyedTask';
use Config::Tiny ();

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.06';
}





#####################################################################
# Constructor

=pod

=head2 new %args

The C<new> constructor takes a set of named arguments in the same way
as the main L<PPI::Processor::KeyedTask> constructor. However, it
accepts an additional argument beyond the default set.

=over

=item file

The C<file> option sets the location of the Config::Tiny-compatible file
that currently, or will, store the results of the task.

It should be a location on the file-system for which the process has
write permissions.

=back

=cut

sub new {
	my $class = ref $_[0] ? ref shift : shift;
	my %args  = @_;

	# Were we given a file?
	my $file = delete $args{file};
	if ( $file and ! -w $file ) {
		return undef;
	}

	# Create the object
	my $self = $class->SUPER::new( %args ) or return undef;

	# Add the file property
	$self->{file} = $file;

	$self;
}





#####################################################################
# PPI::Processor::Task Methods

sub init_store {
	my $self = shift;

	if ( $self->{file} and -f $self->{file} ) {
		$self->{store} = Config::Tiny->read( $self->{file} ) or return undef;
	} else {
		$self->{store} = Config::Tiny->new;
	}

	1;
}

sub end_store {
	my $self = shift;

	# Save the file if we know where to write to
	if ( $self->{file} and -w $self->{file} ) {
		$self->store->write( $self->{file} ) or return undef;
	}

	1;
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

L<PPI::Processor::KeyedTask>, L<PPI::Processor::Task>,
L<PPI::Processor>, L<PPI>, L<Config::Tiny>.

=cut
