use strict;
use warnings;

use Test::More;
use if $ENV{AUTHOR_TESTING}, 'Test::Warnings';
use Test::DZil;
use Path::Tiny;
use utf8;

binmode $_, ':encoding(UTF-8)' foreach map { Test::Builder->new->$_ } qw(output failure_output todo_output);
binmode STDOUT, ':encoding(UTF-8)';
binmode STDERR, ':encoding(UTF-8)';

use Test::File::ShareDir
    -share => {
        -dist => { 'Some-Other-Dist' => 't/corpus' },
    };

{
    package Some::Other::Dist;
    $Some::Other::Dist::VERSION = '2.0';
}

my $tzil = Builder->from_config(
    { dist_root => 'does-not-exist' },
    {
        add_files => {
            path(qw(source dist.ini)) => simple_ini(
                [ 'GenerateFile::ShareDir' => {
                    '-dist' => 'Some-Other-Dist',
                    '-encoding' => 'Latin1',
                    '-source_filename' => 'template_latin1.txt',
                    '-destination_filename' => 'data/useless_file.txt',
                    '-location' => 'root',
                    '-phase' => 'build',
                    numero => 'neuf',
                } ],
            ),
        },
    },
);

$tzil->chrome->logger->set_debug(1);
$tzil->build;

my $build_dir = $tzil->tempdir->subdir('build');
my $nonfile = path( $build_dir, 'data', 'useless_file.txt' );
ok( !-e $nonfile, 'file not created in build' );

my $source_dir = $tzil->tempdir->subdir('source');
my $file = path( $source_dir, 'data', 'useless_file.txt' );
ok( -e $file, 'file created in source' );

my $content = Encode::decode('Latin1', $file->slurp_raw, Encode::FB_CROAK());

my $zilla_version = Dist::Zilla->VERSION;

like($content, qr/^This file was generated with Dist::Zilla::Plugin::GenerateFile::ShareDir /, '$plugin is passed to the template');
like($content, qr/Dist::Zilla $zilla_version/, '$zilla is passed to the template');
like($content, qr/Some-Other-Dist-2.0/, 'dist name can be fetched from the $plugin object');
like($content, qr/Le numéro de Maurice Richard est neuf./, 'arbitrary args are passed to the template');

diag 'got log messages: ', explain $tzil->log_messages
    if not Test::Builder->new->is_passing;

done_testing;
