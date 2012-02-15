package Catalyst::TraitFor::Model::DBIC::Schema::FromMigration::_MigrationHelper;

use Moose;
use DBIx::Class::Migration;

has 'schema_class',
  is => 'ro';

has 'extra_migration_args',
  is => 'ro',
  isa => 'HashRef',
  default => sub { +{} },
  auto_deref => 1;

has 'install_if_needed',
  is => 'ro',
  isa => 'HashRef|Bool',
  predicate => 'has_install_if_needed';

has 'migration',
  is => 'ro',
  lazy_build => 1;

sub _build_migration {
  my $self = shift;
  return DBIx::Class::Migration->new(
    schema_class => $self->schema_class,
    $self->extra_migration_args);
}

sub do_install_if_needed {
  my $self = shift;
  if($self->has_install_if_needed) {
    if(ref $self->install_if_needed) {
      $self->migration->install_if_needed(%{$self->install_if_needed})
    } else {
      $self->migration->install_if_needed;
    }
  }
}

1;

=head1 NAME

Catalyst::TraitFor::Model::DBIC::Schema::FromMigration::_MigrationHelper - Trait Helper

=head1 SYNOPSIS

    use Catalyst::TraitFor::Model::DBIC::Schema::FromMigration::_MigrationHelper;
    
=head1 DESCRIPTION

This is a helper for L<Catalyst::TraitFor::Model::DBIC::Schema::FromMigration>.
There are no 'user servicable' parts here, this is a private class that exposes
a bit of L<DBIx::Class::Migration> to make hooking up an existing migration
database sandbox to L<Catalyst> easier and error free.

=head1 SEE ALSO

L<Catalyst::Model::DBIC::Schema>, L<Catalyst>, L<DBIx::Class::Migration>
L<Catalyst::TraitFor::Model::DBIC::Schema::FromMigration>

=head1 AUTHOR

See L<DBIx::Class::Migration> for author information

=head1 COPYRIGHT & LICENSE

=cut
