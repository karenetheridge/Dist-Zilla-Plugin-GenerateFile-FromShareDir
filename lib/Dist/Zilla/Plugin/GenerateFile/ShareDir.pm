use strict;
use warnings;
package Dist::Zilla::Plugin::GenerateFile::ShareDir;
# ABSTRACT: Create files in the build, based on a template located in a dist sharedir
# vim: set ts=8 sw=4 tw=78 et :

use Moose;
with (
    'Dist::Zilla::Role::FileGatherer',
    'Dist::Zilla::Role::FileMunger',
    'Dist::Zilla::Role::TextTemplate',
);

use MooseX::SlurpyConstructor;
use Scalar::Util 'blessed';
use File::ShareDir 'dist_file';
use Path::Tiny;
use Encode;
use namespace::autoclean;

has dist => (
    is => 'ro', isa => 'Str',
    init_arg => '-dist',
    lazy => 1,
    default => sub { (my $dist = blessed(shift)) =~ s/::/-/g; $dist },
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

    $config->{'' . __PACKAGE__} = {
        # XXX FIXME - it seems META.* does not like the leading - in field
        # names! something is wrong with the serialization process.
        'dist' => $self->dist,
        'encoding' => $self->encoding,
        'source_filename' => $self->source_filename,
        'destination_filename' => $self->filename,
        $self->_extra_args,
    };
    return $config;
};

sub gather_files
{
    my $self = shift;

    require Dist::Zilla::File::InMemory;

    # this should die if the file does not exist
    my $file = dist_file($self->dist, $self->source_filename);

    my $content = path($file)->slurp_raw;
    $content = Encode::decode($self->encoding, $content, Encode::FB_CROAK());

    $self->add_file(Dist::Zilla::File::InMemory->new(
        name => $self->filename,
        encoding => $self->encoding,    # only used in Dist::Zilla 5.000+
        content => $content,
    ));
}

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
    $content = Encode::encode($self->encoding, $content, Encode::FB_CROAK()) if Dist::Zilla->VERSION < 5.000;

    $file->content($content);
}

__PACKAGE__->meta->make_immutable;
__END__

=pod

=for Pod::Coverage::TrustPod
    gather_files
    munge_file

=head1 SYNOPSIS

In your F<dist.ini>:

    [GenerateFile::ShareDir]
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
plugin that subclasses this one.

=head1 OPTIONS

This plugin accepts the following options:

=over 4

=item * C<-dist>

=for stopwords sharedir

The distribution name to use when finding the sharedir (see L<File::ShareDir>
and L<Dist::Zilla::Plugin::ShareDir>). Defaults to the dist corresponding to
the running plugin.

=item * C<-destination_filename> or C<-filename>

The filename to generate in the distribution being built. Required.

=item * C<-source_filename>

The filename in the sharedir to use to generate the new file. Defaults to the
same filename and path as C<-destination_file>.

=item * C<-encoding>

The encoding of the source file; will also be used for the encoding of the
destination file. Defaults to UTF-8.

=item * C<arbitrary option>

All other keys/values provided will be passed to the template as is.

=back

=head1 SUPPORT

=for stopwords irc

Bugs may be submitted through L<the RT bug tracker|https://rt.cpan.org/Public/Dist/Display.html?Name=Dist-Zilla-Plugin-GenerateFile-ShareDir>
(or L<bug-Dist-Zilla-Plugin-GenerateFile-ShareDir@rt.cpan.org|mailto:bug-Dist-Zilla-Plugin-GenerateFile-ShareDir@rt.cpan.org>).
I am also usually active on irc, as 'ether' at C<irc.perl.org>.

=head1 SEE ALSO

=begin :list

* L<File::ShareDir>
* L<Dist::Zilla::Plugin::ShareDir>
* L<Text::Template>

=end :list

=cut
