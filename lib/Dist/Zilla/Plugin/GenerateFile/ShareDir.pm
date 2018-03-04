use strict;
use warnings;
package Dist::Zilla::Plugin::GenerateFile::ShareDir;
# vim: set ts=8 sts=4 sw=4 tw=115 et :
# ABSTRACT: (DEPRECATED) Create files in the repository or in the build, based on a template located in a distribution sharedir

our $VERSION = '0.014';

use Moose;
extends 'Dist::Zilla::Plugin::GenerateFile::FromShareDir';
use namespace::autoclean;

before register_component => sub {
    warnings::warnif('deprecated',
        "!!! [GenerateFile::ShareDir] is deprecated and may be removed in a future release; replace it with [GenerateFile::FromShareDir]\n",
    );
};

__PACKAGE__->meta->make_immutable;
__END__

=pod

=for :header
=for stopwords sharedir

=head1 SYNOPSIS

In your F<dist.ini>:

    [GenerateFile::FromShareDir]
    ...

=head1 DESCRIPTION

THIS MODULE IS DEPRECATED. Please use
L<Dist::Zilla::Plugin::Generatefile::ShareDir> instead. it may be removed at a
later time (but not before April 2016).

In the meantime, it will continue working -- although with a warning.
Refer to the replacement for the full documentation.

=cut
