package DBIx::Class::Migration::Script;

use Moose;
use DBIx::Class::Migration;

with 'MooseX::Getopt';

has migration => (
  is => 'ro',
  lazy_build => 1);

has includes => (
  traits => ['Getopt'],
  is => 'ro',
  isa => 'ArrayRef',
  predicate => 'has_includes',
  cmd_aliases => ['I', 'libs']);

has schema_class => (traits => [ 'Getopt' ], is => 'ro', isa => 'Str', predicate=>'has_schema_class', cmd_aliases => 'S');
has target_dir => (traits => [ 'Getopt' ], is => 'ro', isa=> 'Str', predicate=>'has_target_dir', cmd_aliases => 'dir');
has username => (traits => [ 'Getopt' ], is => 'ro', isa => 'Str', default => '', , cmd_aliases => 'U');
has password => (traits => [ 'Getopt' ], is => 'ro', isa => 'Str', default => '', cmd_aliases => 'P');
has dsn => (traits => [ 'Getopt' ], is => 'ro', isa => 'Str');
has force_overwrite => (traits => [ 'Getopt' ], is => 'ro', isa => 'Bool', default => 0, cmd_aliases => 'O');
has to_version => (traits => [ 'Getopt' ], is => 'ro', isa => 'Int', predicate=>'has_to_version', cmd_aliases => 'V');

has databases => (traits => [ 'Getopt' ], is => 'ro', isa => 'ArrayRef', 
  lazy_build => 1, predicate=>'has_databases', cmd_aliases => 'database');

has fixture_sets => (
  traits => [ 'Getopt' ],
  is=>'ro',
  isa=>'ArrayRef',
  default => sub { +['all'] },
  cmd_aliases => 'fixture_set');

has migration => (
  is => 'ro',
  lazy_build => 1,
  handles=>{
    cmd_version=>'version',
    cmd_status=>'status',
    cmd_prepare=>'prepare',
    cmd_install=>'install',
    cmd_upgrade=>'upgrade',
    cmd_downgrade=>'downgrade',
    cmd_drop_tables=>'drop_tables',
    cmd_delete_table_rows=>'delete_table_rows',
    cmd_dump_all_sets=>'dump_all_sets'});

sub _build_migration {
  my $self = shift;
  my @schema_args;
  if($self->dsn) {
    push @schema_args, $self->dsn;
    push @schema_args, $self->username;
    push @schema_args, $self->password;
  }

  return DBIx::Class::Migration->new(
    schema_class => $self->schema_class,
    (@schema_args ? (schema_args=>\@schema_args) : ()),
    dbic_dh_args => {
      force_overwrite => $self->force_overwrite,
      ($self->has_target_dir ? (script_directory=>$self->target_dir) : ()),
      ($self->has_to_version ? (to_version=>$self->to_version) : ()),
      ($self->has_databases ? (databases=>$self->databases) : ()),
    }
  );
}

sub cmd_dump_named_sets {
  my $self = shift;
  $self->migration->dump_named_sets(@{$self->fixture_sets});
}

sub cmd_populate {
  my $self = shift;
  $self->migration->cmd_populate(@{$self->fixture_sets});
}

sub _import_libs {
  my ($self, @libs) = @_;
  require lib;
  lib->import(@libs);
}

sub run {
  my ($self) = @_;
  my ($cmd, @extra_argv) = @{$self->extra_argv};

  $self->_import_libs(@{$self->includes})
    if $self->has_includes;

  die "Must supply a command\n" unless $cmd;
  die "Extra argv detected - command only please\n" if @extra_argv;
  die "No such command ${cmd}\n" unless $self->can("cmd_${cmd}");

  $self->${\"cmd_${cmd}"};
}

sub run_if_script {
  my $class = shift;
  caller(1) ? 1 : $class->new_with_options()->run;
}

__PACKAGE__->meta->make_immutable;
__PACKAGE__->run_if_script;

=head1 NAME

DBIx::Class::Migration::Script - Tools to manage database Migrations

=head1 SYNOPSIS

    dbic-migration status \
      --libs="lib"
      --schema_class='MyApp::Schema' \
      --dns='DBI:SQLite:myapp.db'

=head1 DESCRIPTION

This is a class which is provider interface mapping between the commandline
script L<dbic-migration> and the back end code that does the heavy lifting,
L<DBIx::Class::Migration>.  This class has very little of it's own
functionality, since it basically acts as processing glue between that
commandline application and the code which does all the work.

You should look at L<DBIx::Class::Migration> and the tutorial over at
L<DBIx::Class::Migration::Tutorial> to get started.  This is basically
API level docs and a command summary which is likely to be useful as a
reference when you are familiar with the system.

=head1 ATTRIBUTES

This class defines the following attributes.

=head2 includes

Accepts ArrayRef. Not required.

Similar to the commandline switch C<I> for the C<perl> interpreter.  It adds
to C<@INC> for when we want to search for modules to load.  This is primarily
useful for specifying a path to find a L</schema_class>.

We make no attempt to check the validity of any paths specified.  Buyer beware.

=head2 schema_class

Accepts Str.  Required.

This is the schema we use as the basic for creating, managing and running your
deployments.  This should be the full package namespace defining your subclass
of L<DBIx::Class::Schema>.  For example C<MyApp::Schema>.

If you don't prove this, we will try to guess it by looking for a C<::Schema>
class in the parent namespace.  This will only work if you create a custom
subclass of L<App::DBIx::Class::Migration> for your project.  For example, if
you have a class C<MyApp::Schema::Migration> which is a subclass of
L<App::DBIx::Class::Migration>, we will assume C<MyApp::Schema> is a subclass
of L<DBIx::Class::Schema> and assume that is the name of the L</schema_class>
you wish to use.

If the L</schema_class> cannot be loaded, a hard exception will be thrown.

=head2 target_dir

Accepts Str.  Required.

This is the directory we store our migration and fixture files.  Inside this
directory we will create a C<fixtures> and C<migrations> sub-directory.

Although you can specify the directory, if you leave it undefined, we will use
L<File::ShareDir::ProjectDistDir> to locate the C<share> directory for your
project and place the files there.  This is the recommended approach, and is
considered a community practice in regards to where to store your distribution
non code files.  Please see L<File::ShareDir::ProjectDistDir> as well as
L<File::ShareDir> for more information.

=head2 username

Accepts Str.  Not Required

This should be the username for the database we connect to for deploying
ddl, ddl changes and fixtures.

=head2 password

Accepts Str.  Not Required

This should be the password for the database we connect to for deploying
ddl, ddl changes and fixtures.

=head2 dsn

Accepts Str.  Not Required

This is the DSN for the database you are going to be targeting for deploying
or altering ddl, and installing or generating fixtures.

This should be a DSN suitable for L<DBIx::Class::Schema/connect), something
in the form of C<DBI:SQLite:myapp-schema.db)>.

Please take care where you point this (like production :) )

If you don't provide a value, we will automatically create a SQLite based
database connection with the following DSN:

    DBD:SQLite:[path to target_dir]/[db_file_name].db

Where c<[path to target_dir]> is L</target_dir> and [db_file_name] is a converted
version of L</schema_class>.  For example if you set L<schema_class> to:

    MyApp::Schema

Then [db_file_name] would be C<myapp-schema>.

Please remember that you can generate deployment files for database types
other than the one you've defined in L</dsn>, however since different databases
enforce constraints differently it would not be impossible to generate fixtures
that can be loaded by one database but not another.  Therefore I recommend
always generated fixtures from a database that is consistent across enviroments.

=head2 force_overwrite

Accepts Bool.  Not Required.  Defaults to False.

Used when building L</_dh> to en / disable  the L<DBIx::Class::DeploymentHandler>
option C<force_overwrite>.  This is used when generating DDL and related
files for a given version of your L</_schema> to decide if it is ok to overwrite
deployment files.  You might need this if you deploy a version of the database
during development and then need to make more changes or fixes for that version.

=head2 to_version

Accepts Int.  Not Required.

Used to establish a target version when running an install.  You can use this
to force install a version of the database other then your current L</_schema>
version.  You might want this when you need to force install a lower version as
part of your development process for changing the database.

If you leave this undefined, no default value is built, however
L<DBIx::Class::DeploymentHandler> will assume you want whatever is the value of
your $schema->version.

=head2 databases

Accepts ArrayRef.  Not Required.

Used when building L</_dh> to define the target databases we are building
migration files for.  You can name any of the databases currently supported by
L<SQLT>.  If you leave this undefined we will derive a value based on the value
of L</dsn>.  For example, if your L</dsn> is "DBI:SQLite:test.db", we will set
the valuye of L</databases> to C<['SQLite']>.

=head2 fixture_sets

Accepts ArrayRef.  Not Required. Defaults to ['all'].

This defines a list of fixture sets that we use for dumping or populating
fixtures.  Defaults to the C<['all']> set, which is the one set we build
automatically for each version of the database we prepare deployments for.

=head1 COMMANDS

    dbic_migration -Ilib install

Since this class consumes the L<MooseX::GetOpt> role, it can be run directly
as a commandline application.  The following is a list of commands we support
as well as the options / flags associated with each command.

=head2 flags

The following flags are used to modify or inform commands.

=head3 includes

Aliases: I, lib
Value: String or Array of Strings

    dbic_migration --includes lib --includes /opt/perl/lib

Does the same thing as the Perl command line interpreter flag C<I>.  Adds all
the listed paths to C<@INC>.  You will likely use this in order to find your
application schema (subclass of L<DBIx::Class::Schema>.

=head3 schema_class

Value: Str

    dbic_migration prepare --schema_class MyApp::Schema -Ilib

Used to specify the L<DBIx::Class::Schema> subclass which is the core of your
L<DBIx::Class> based ORM managed system.  This is required and the application
cannot function without one.

=head3 target_dir

Aliases: D
Value: Str

    dbic_migration prepare --schema_class MyApp::Schema --target_dir /opt/share

We need a directory path that is used to store your fixtures and migration
files.  By default this will be the C<share> directory for the application
where your L</schema_class> resides.  I recommend you leave it alone since
this is a reasonable Perl convention for non code data, and there's a decent
ecosystem of tools around it, however if you need to place the files in an
alternative location (for example you have huge fixture sets and you don't
want them in you core repository, or you can't store them in a limited space
filesystem) this will let you do it.  Option and defaults as discussed.

=head3 username

Aliases: U
Value:  Str

=head3 password

Aliases: P
Value: String

=head3 dsn

Value: String

These three commandline flags describe how to connect to a target, physical
database, where we will deploy migrations and fixtures.  If you don't provide
them, we will automatically deploy to a L<DBD::SQLite> managed database located
at L</target_dir>.

    dbic_migration install --username myuser --password mypass --dsn DBI:SQLite:mydb.db

=head3 deployment_handler_class

Value: Str

Lets you use something other than L<DBIx::Class::DeploymentHandler> as your
base class for created deployment handlers.  You might wish to change this if
you have a custom version of the deployment tool.

=head3 overwrite_migrations

Aliases: O
Value: Bool (default: False)

Sometimes you may wish to prepare migrations for the same version more than
once (say if you are developing a new version and need to try out a few options
first).  This lets you deploy over an existing set.  This will of course destroy
and manual modifications you made, buyer beware.)

    dbic_migration prepare --overwrite_migrations

=head3 drop_tables

Aliases: D
Value: Bool (default: False)

Used to influence how L<SQLT> created a DDL for your migration.  If this is
enabled, we add a 'drop table $TABLE' statement before each create table
statement.  Personally I used the command 'drop_tables', but you might prefer
this method.

=head3 to_version

Aliases: D
Value: Str (default: Current VERSION of Schema)

    dbic_migration install --to_version 5

Used to specify which version we are going to deploy.  Defaults to whatever
is the most current version you've prepared.

Use this when you need to force install an older version, such as when you are
roundtripping prepares while fiddling with a new database version.

=head3 databases

Alias: database
Value: Str or Array of Str (default: SQLite)

You can prepare deployment for any database type that L<SQLT> understand.  By
default we only prepare a deployment version for the database which matches
the L<dsn> you specified but you can use this to prepare additional deployments

    dbic_migration prepare --database SQLite --database mysql

Please note if you choose to manually set this value, you won't automatically
get the default, unless you specify as above

=head3 dbic_fixtures_class

Value: Str (default: DBIx::Class::Fixtures)

If you've created a custom subclass of L<DBIx::Class::Fixtures> and want to use
it, this is how to do it.

=head3 overwrite_fixtures

Value: Bool (default: False)

Lets you overwrite previously created fixtures for a given schema version.

=head3 fixture_sets

Alias: fixture_set
Value: Str or Array of Str (default: all set)

When dumping or populating fixture sets, you use this to set which sets.

    dbic_migration dump --fixture_set roles --fixture_set core

Please note that if you manually describe your sets as in the above example,
you don't automatically get the C<all> set, which is a fixture set of all
database information and not 'all' the sets.

We automatically create the C<all> fixture set description file for you when
you prepare a new migration of the schema.  You can use this set for early
testing but I recommend you study L<DBIx::Class::Fixtures> and learn the set
configuration rules, and create limited fixture sets for given purposes, rather
than just dump / populate everything, since that is like to get big pretty fast

My recommendation is to create a core 'seed' set, of default database values,
such as role types, default users, lists of countries, etc. and then create a
'demo' or 'dev' set that contains extra information useful to populate a
database so that you can run test cases and develop against.

=head2 help

Summary of commands and aliases.

=head2 version

prints the current version of the application to STDOUT

=head2 status

Returns the state of the deployed database (if it is deployed) and the state
of the current C<schema>

=head2 prepare

Creates a C<fixtures> and C<migrations> directory under L</target_dir> (if they
don't already exist) and makes deployment files for the current schema.  If
deployment files exist, will fail unless you L</overwrite_migrations> and
L</overwrite_fixtures>.

=head2 install

Installs either the current schema version (if already prepared) or the target
version specified via L</to_version> to the database connected via the L</dsn>,
L</username> and L</password>

=head2 upgrade

Run upgrade files to either bring the database into sync with the current
schema version, or stop at an intermediate version specified via L</to_version>

=head2 downgrade

Run down files to bring the database down to the version specified via
L</to_version>

=head2 dump

Given listed L<fixture_sets>, dump files for the current database version (not
the current schema version)

=head2 populate

Given listed L<fixture_sets>, populate a database with fixtures for the matching
version (matches database version to fixtures, not the schema version)

=head2 drop_tables

Drops all the tables in the connected database with no backup or recovery.  For
real! (Make sure you are not connected to Prod, for example)

=head2 delete_table_rows

does a C<delete> on each table in the database, which clears out all your data
but preserves tables.  For Real!  You might want this if you need to load
and unload fixture sets during testing, or perhaps to get rid of data that
accumulated in the database while running an app in development, before dumping
fixtures.

Skips the table C<dbix_class_deploymenthandler_versions>, so you don't lose
deployment info (this is different from L</drop_tables> which does delete it.)

=head1 AUTHOR

John Napiorkowski L<email:jjnapiork@cpan.org>

=head1 SEE ALSO

L<DBIx::Class::Migrations>, L<MooseX::Getopt>.

=head1 COPYRIGHT & LICENSE

Copyright 2012, John Napiorkowski L<email:jjnapiork@cpan.org>

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
