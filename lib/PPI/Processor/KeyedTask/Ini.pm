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
	$VERSION = '0.12';
}





#####################################################################
# Constructor

=pod

=head2 new %args

The C<new> constructor takes a set of named arguments in the same way
as the main L<PPI::Processor::KeyedTask> constructor. However, it
accepts several additional arguments beyond the defaults.

=over

=item file

The C<file> option sets the location of the Config::Tiny-compatible file
that currently, or will, store the results of the task.

It should be a location on the file-system for which the process has
write permissions.

=item incremental_write

To handle situations in which the processor might be killed or suffer
some other problem which would prevent the results from being written,
you can provide the incremental_write value.

If set to true, and you have provided a filename, the Task object will
attempt to write to the config file every time it recieves a C<store_file>
call.

=back

=cut

sub new {
	my $class = ref $_[0] ? ref shift : shift;
	my %args  = @_;

	# Check the file argument
	my $file = delete $args{file};
	$class->_check_file($file) or return undef;

	# Create the object
	my $self = $class->SUPER::new( %args ) or return undef;

	# Set the file
	$self->{file} = $file;

	# Do we want to store incrementally as we go?
	$self->{incremental_write} = !! $args{incremental_write};

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

	# Save the file at end time
	$self->_write_file or return undef;
	$self->{end_store} = 1;
}

sub store_file {
	my $self = shift;
	$self->SUPER::store_file(@_) or return undef;

	# Save the store now if needed
	if ( $self->{incremental_write} ) {
		$self->_write_file or return undef;
	}

	1;	
}

# Automatically write the results on a premature destroy
sub DESTROY {
	$_[0]->end_store unless $_[0]->{end_store};
	1;
}





#####################################################################
# Support Methods

sub _check_file {
	my ($class, $file) = @_;
	return 1 unless $file;
	return 1 if -w $file;

	# File does not exist.
	# Can we write to the parent directory?
	my ($v, $d, $f) = File::Spec->splitpath( $file );
	my $dir = File::Spec->catpath( $v, $d );
	return '' unless -e $dir;
	return '' unless -d $dir;
	return -w $dir;
}

# Write out the config object.
sub _write_file {
	my $self = shift;
	return 1 unless $self->{file};
	my $store = $self->{store} or return undef;
	$store->write( $self->{file} );
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
