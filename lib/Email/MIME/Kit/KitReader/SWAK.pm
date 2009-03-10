package Email::MIME::Kit::KitReader::SWAK;
use Moose;
with 'Email::MIME::Kit::Role::KitReader';
# ABSTRACT: the swiss army knife of EMK kit readers

=head1 DESCRIPTION

This replaces and extends the standard (Dir) kit reader for Email::MIME::Kit,
letting your kit refer to resources in locations other than the kit itself.

In your manifest (assuming it's YAML, for readability):

  ---
  kit_reader: SWAK
  attachments:
  - type: text/html
    path: template.html

  - type: text/plain
    path: /dist/Your-App/config.conf

  - type: text/plain
    path: /fs/etc/motd

This will find the first file in the kit (the absolute path prefix F</kit>
could also be used), the second file in the L<File::ShareDir|File::ShareDir>
shared dist space for the Your-App, and the third file on the root filesystem.

SWAK may be given a C<fs_root> option to start the contents of F</fs> somewhere
other than root.

=cut

use Path::Resolver::Resolver::Mux::Prefix;
use Path::Resolver::Resolver::FileSystem;
use Path::Resolver::Resolver::AnyDist;

has resolver => (
  is       => 'ro',
  does     => 'Path::Resolver::Role::Resolver',
  init_arg => undef,
  lazy     => 1,
  default  => sub {
    my ($self) = @_;
    my $prs = sub { 'Path::Resolver::Resolver::' . $_[0] };

    my $old_kr = $self->kit->kit_reader;
    confess(__PACKAGE__ . ' must (for now) replace an existing KitReader::Dir')
      unless $old_kr and $old_kr->isa('Email::MIME::Kit::KitReader::Dir');
    
    my $kit_resolver = $prs->('FileSystem')->new({
      root => $self->kit->source,
    });

    Path::Resolver::Resolver::Mux::Prefix->new({
      prefixes => {
        fs   => $prs->('FileSystem')->new({ root => $self->fs_root }),
        dist => $prs->('AnyDist')->new,
        kit  => $kit_resolver,
        q{}  => $kit_resolver,
      },
    });
  },
);

has fs_root => (
  is  => 'ro',
  isa => 'Str',
  default => '/',
);

sub get_kit_entry {
  my ($self, $path) = @_;

  my $content = $self->resolver->content_for($path);
  return $content if $content;

  confess "no content for $path";
}

sub BUILD {
  my ($self) = @_;
  $self->resolver;
}

no Moose;
__PACKAGE__->meta->make_immutable;
