package Mad::Mapper;

=head1 NAME

Mad::Mapper - Map Perl objects to MySQL or PostgreSQL row data

=head1 VERSION

0.01

=head1 DESCRIPTION

L<Mad::Mapper> is a object to database adapter.

=head1 SYNOPSIS

=head2 Simple

  package User;
  use Mad::Mapper -base;

  has email => '';
  has id => undef;

  sub _find { 'SELECT id, email FROM users WHERE email = ?', $_[0]->email }
  sub _delete { 'DELETE FROM users WHERE id = ?', $_[0]->id }
  sub _insert { 'INSERT INTO users ("email") VALUES(?)', $_[0]->email }
  sub _update { 'UPDATE users SET email = ? WHERE id = ?', $_[0]->email, $_[0]->id }

=head2 Complex

  package User;
  use Mad::Mapper -base;

  has email => '';
  has id => undef;

  sub _delete {
    my ($self, $cb) = @_;

    Mojo::IOLoop->delay(
      sub {
        my ($delay) = @_;
        $self->db->query('DELETE FROM users WHERE id = ?', $self->id, $delay->begin);
      },
      sub {
        my ($delay, $err, $res) = @_;
        $self->in_storage(0) unless $err;
        $self->$cb($err);
      },
    );
  }

  sub _find {
    my ($self, $cb) = @_;

    Mojo::IOLoop->delay(
      sub {
        my ($delay) = @_;
        $self->db->query('SELECT id, email FROM users WHERE email = ?', $self->email, $delay->begin);
      },
      sub {
        my ($delay, $err, $res) = @_;
        return $self->$cb($err) if $err;
        $self->in_storage(1) unless $err;
        $res = $res->hash;
        $self->$_ = $res->{$_} for qw( id email );
      },
    );
  }

  sub _insert {
    my ($self, $cb) = @_;

    Mojo::IOLoop->delay(
      sub {
        my ($delay) = @_;
        $self->db->query('INSERT INTO users ("email") VALUES(?)', $self->email, $delay->begin);
      },
      sub {
        my ($delay, $err, $res) = @_;
        return $self->$cb($err) if $err;
        $self->in_storage(1);
        $self->id($res->sth->mysql_insertid);
        $self->$cb('');
      },
    );
  }

  sub _update {
    my ($self, $cb) = @_;

    Mojo::IOLoop->delay(
      sub {
        my ($delay) = @_;
        $self->db->query('UPDATE users SET email = ? WHERE id = ?', $self->email, $self->id, $delay->begin);
      },
      sub {
        my ($delay, $err, $res) = @_;
        $self->$cb($err);
      },
    );
  }

=cut

use Mojo::Base -base;
use Mojo::IOLoop;

our $VERSION = '0.01';

=head1 ATTRIBUTES

=head2 db

  $db = $self->db;
  $self->db($db_obj);

Need to hold either a L<Mojo::Pg::Database> or L<Mojo::mysql::Database> object.

=head2 in_storage

  $bool = $self->in_storage;
  $self = $self->in_storage($bool);

=cut

has db => sub { die "'db' is required in constructor." };
has in_storage => 0;

=head1 METHODS

=head2 delete

  $self = $self->delete;
  $self = $self->delete(sub { my ($self, $err) = @_, ... });

Will delete the object from database if L</in_storage>.

=cut

sub delete {
  my ($self, $cb) = @_;

  if ($cb) {
    $self->in_storage ? $self->_delete($cb) : $self->$cb('');
    return $self;
  }

  my $err;
  $cb = sub { (my $self, $err) = @_; Mojo::IOLoop->stop; };
  $self->_delete($cb) if $self->in_storage;
  die $err if $err;
  return $self;

}

=head2 save

  $self = $self->save;
  $self = $self->save(sub { my ($self, $err) = @_, ... });

Will update the object in database if L</in_storage> or insert it if not.

=cut

sub save {
  my ($self, $cb) = @_;

  if ($cb) {
    $self->in_storage ? $self->_update($cb) : $self->_insert($cb);
    return $self;
  }

  my $err;
  $cb = sub { (my $self, $err) = @_; Mojo::IOLoop->stop; };
  $self->in_storage ? $self->_update($cb) : $self->_insert($cb);
  die $err if $err;
  return $self;
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
