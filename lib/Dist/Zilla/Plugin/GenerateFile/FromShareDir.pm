use strict;
use warnings;
package Dist::Zilla::Plugin::GenerateFile::FromShareDir;
# ABSTRACT: Create files in the repository or in the build, based on a template located in a dist sharedir
# KEYWORDS: plugin distribution generate create file sharedir template
# vim: set ts=8 sts=4 sw=4 tw=115 et :

our $VERSION = '0.010';

use Moose;
with (
    'Dist::Zilla::Role::FileGatherer',
    'Dist::Zilla::Role::FileMunger',
    'Dist::Zilla::Role::TextTemplate',
    'Dist::Zilla::Role::RepoFileInjector',
    'Dist::Zilla::Role::AfterBuild',
    'Dist::Zilla::Role::AfterRelease',
);

use MooseX::SlurpyConstructor 1.2;
use Moose::Util 'find_meta';
use File::ShareDir 'dist_file';
use Path::Tiny 0.04;
use Encode;
use Moose::Util::TypeConstraints 'enum';
use namespace::autoclean;

has dist => (
    is => 'ro', isa => 'Str',
    init_arg => '-dist',
    lazy => 1,
    default => sub { (my $dist = find_meta(shift)->name) =~ s/::/-/g; $dist },
);

has filename => (
    init_arg => '-destination_filename',
    is => 'ro', isa => 'Str',
    required => 1,
);

has source_filename => (
    init_arg => '-source_filename',
    is => 'ro', isa => 'Str',
    lazy => 1,
    default => sub { shift->filename },
);

has encoding => (
    init_arg => '-encoding',
    is => 'ro', isa => 'Str',
    lazy => 1,
    default => 'UTF-8',
);

has location => (
    is => 'ro', isa => enum([ qw(build root) ]),
    lazy => 1,
    default => 'build',
    init_arg => '-location',
);

has phase => (
    is => 'ro', isa => enum([ qw(build release) ]),
    lazy => 1,
    default => 'release',
    init_arg => '-phase',
);

has _extra_args => (
    isa => 'HashRef[Str]',
    init_arg => undef,
    lazy => 1,
    default => sub { {} },
    traits => ['Hash'],
    handles => { _extra_args => 'elements' },
    slurpy => 1,
);

around BUILDARGS => sub
{
    my $orig = shift;
    my $class = shift;

    my $args = $class->$orig(@_);
    $args->{'-destination_filename'} = delete $args->{'-filename'} if exists $args->{'-filename'};

    return $args;
};

around dump_config => sub
{
    my ($orig, $self) = @_;
    my $config = $self->$orig;

    $config->{+__PACKAGE__} = {
        # XXX FIXME - it seems META.* does not like the leading - in field
        # names! something is wrong with the serialization process.
        'dist' => $self->dist,
        'encoding' => $self->encoding,
        'source_filename' => $self->source_filename,
        'destination_filename' => $self->filename,
        'location' => $self->location,
        $self->location eq 'root' ? ( 'phase' => $self->phase ) : (),
        blessed($self) ne __PACKAGE__ ? ( version => $VERSION ) : (),
        $self->_extra_args,
    };
    return $config;
};

sub gather_files
{
    my $self = shift;

    # this should die if the file does not exist
    my $file_path = dist_file($self->dist, $self->source_filename);

    my $content = path($file_path)->slurp_raw;
    $content = Encode::decode($self->encoding, $content, Encode::FB_CROAK());

    require Dist::Zilla::File::InMemory;
    my $file = Dist::Zilla::File::InMemory->new(
        name => $self->filename,
        encoding => $self->encoding,    # only used in Dist::Zilla 5.000+
        content => $content,
    );

    if ($self->location eq 'build')
    {
        $self->add_file($file);
    }
    else
    {
        # root eq $self->location
        $self->add_repo_file($file);
    }
    return;
}

around munge_files => sub
{
    my ($orig, $self, @args) = @_;

    return $self->$orig(@args) if $self->location eq 'build';

    for my $file ($self->_repo_files)
    {
        if ($file->can('is_bytes') and $file->is_bytes)
        {
            $self->log_debug([ '%s has \'bytes\' encoding, skipping...', $file->name ]);
            next;
        }
        $self->munge_file($file);
    }
};

sub munge_file
{
    my ($self, $file) = @_;

    return unless $file->name eq $self->filename;
    $self->log_debug([ 'updating contents of %s in memory', $file->name ]);

    my $content = $self->fill_in_string(
        $file->content,
        {
            $self->_extra_args,     # must be first
            dist => \($self->zilla),
            plugin => \$self,
        },
    );

    # older Dist::Zilla wrote out all files :raw, so we need to encode manually here.
    $content = Encode::encode($self->encoding, $content, Encode::FB_CROAK()) if not $file->can('encoded_content');

    $file->content($content);
}

sub after_build
{
    my $self = shift;
    $self->write_repo_files if $self->phase eq 'build';
}

sub after_release
{
    my $self = shift;
    $self->write_repo_files if $self->phase eq 'release';
}

__PACKAGE__->meta->make_immutable;
__END__

=pod

=for Pod::Coverage::TrustPod
    gather_files
    munge_file
    after_build
    after_release

=for :header
=for stopwords sharedir

=head1 SYNOPSIS

In your F<dist.ini>:

    [GenerateFile::FromShareDir]
    -dist = Dist::Zilla::PluginBundle::Author::ME
    -source_filename = my_data_template.txt
    -destination_filename = examples/my_data.txt
    key1 = value to pass to template
    key2 = another value to pass to template

=head1 DESCRIPTION

Generates a file in your dist, indicated by C<-destination_file>, based on the
L<Text::Template> located in the C<-source_file> of C<-dist>'s
L<distribution sharedir|File::ShareDir>. Any extra config values are passed
along to the template, in addition to C<$zilla> and C<$plugin> objects.

I expect that usually the C<-dist> that contains the template will be either a
plugin bundle, so you can generate a custom-tailored file in your dist, or a
plugin that subclasses this one.  (Otherwise, you can just as easily use
L<[GatherDir::Template]|Dist::Zilla::Plugin::GatherDir::Template>
or L<[GenerateFile]|Dist::Zilla::Plugin::GenerateFile>
to generate the file directly, without needing a sharedir.)

=head1 OPTIONS

All unrecognized keys/values will be passed to the template as is.
Recognized options are:

=head2 C<-dist>

The distribution name to use when finding the sharedir (see L<File::ShareDir>
and L<Dist::Zilla::Plugin::ShareDir>). Defaults to the dist corresponding to
the running plugin.

=head2 C<-destination_filename> or C<-filename>

The filename to generate in the distribution being built. Required.

=head2 C<-source_filename>

The filename in the sharedir to use to generate the new file. Defaults to the
same filename and path as C<-destination_file>.

=head2 C<-encoding>

The encoding of the source file; will also be used for the encoding of the
destination file. Defaults to UTF-8.

=head2 C<-location>

default: C<build>

The target location of the generated file. When C<build>, the file is added to
the distribution in the normal file gathering phase. When C<root>, the file is
instead written to the source repository.

=head2 C<-phase>

Only relevant when C<-location = root>. When C<build> (the default), the file
is written on every build operation. When C<release>, it is only written after
the distribution is released.

=head1 SEE ALSO

=for stopwords templated

=for :list
* L<File::ShareDir>
* L<Dist::Zilla::Plugin::ShareDir>
* L<Text::Template>
* L<[GatherDir::Template]|Dist::Zilla::Plugin::GatherDir::Template> - gather a file from the dist, and then pass it through a template
* L<[GenerateFile]|Dist::Zilla::Plugin::GenerateFile> - generate a (possibly-templated) file purely based on data in F<dist.ini>

=cut
