use strict;
use warnings FATAL => 'all';

use Test::More;
use if $ENV{AUTHOR_TESTING}, 'Test::Warnings';
use Test::DZil;
use Path::Tiny;
use utf8;
binmode $_, ':utf8' foreach map { Test::Builder->new->$_ } qw(output failure_output);

use Test::File::ShareDir
    -share => {
        -dist => { 'Some-Other-Dist' => 't/corpus' },
    };

{
    package Some::Other::Dist;
    $Some::Other::Dist::VERSION = '2.0';
}

my $tzil = Builder->from_config(
    { dist_root => 't/does_not_exist' },
    {
        add_files => {
            'source/dist.ini' => simple_ini(
                [ 'GenerateFile::ShareDir' => {
                    '-dist' => 'Some-Other-Dist',
                    '-encoding' => 'Latin1',
                    '-source_filename' => 'template_latin1.txt',
                    '-destination_filename' => 'data/useless_file.txt',
                    numero => 'neuf',
                } ],
            ),
        },
    },
);

$tzil->build;

my $build_dir = $tzil->tempdir->subdir('build');
my $file = path($build_dir, 'data', 'useless_file.txt');
ok(-e $file, 'file created');

my $content = Encode::decode('Latin1', $file->slurp_raw, Encode::FB_CROAK());

my $zilla_version = Dist::Zilla->VERSION;

like($content, qr/^This file was generated with Dist::Zilla::Plugin::GenerateFile::ShareDir /, '$plugin is passed to the template');
like($content, qr/Dist::Zilla $zilla_version/, '$zilla is passed to the template');
like($content, qr/Some-Other-Dist-2.0/, 'dist name can be fetched from the $plugin object');
like($content, qr/Le numéro de Maurice Richard est neuf./, 'arbitrary args are passed to the template');

done_testing;
