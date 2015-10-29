use strict;
use warnings;

use Test::More;
use if $ENV{AUTHOR_TESTING}, 'Test::Warnings';
use Test::DZil;
use Path::Tiny;
use Test::Deep;
use utf8;

binmode $_, ':encoding(UTF-8)' foreach map { Test::Builder->new->$_ } qw(output failure_output todo_output);
binmode STDOUT, ':encoding(UTF-8)';
binmode STDERR, ':encoding(UTF-8)';

use Test::File::ShareDir -share => { -dist => { 'Some-Other-Dist' => 't/corpus' } };

{
    package Some::Other::Dist;
    $Some::Other::Dist::VERSION = '2.0';
}

my $tzil = Builder->from_config(
    { dist_root => 'does-not-exist' },
    {
        add_files => {
            path(qw(source dist.ini)) => simple_ini(
                'MetaConfig',
                [ 'GenerateFile::ShareDir' => {
                    '-dist' => 'Some-Other-Dist',
                    '-source_filename' => 'template.txt',
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
my $nonfile = path($build_dir, 'data', 'useless_file.txt');
ok(!-e $nonfile, 'file not created in build');

my $source_dir = $tzil->tempdir->subdir('source');
my $file = path($source_dir, 'data', 'useless_file.txt');
ok(-e $file, 'file created in source');

my $content = $file->slurp_utf8;

like($content, qr/^This file was generated with Dist::Zilla::Plugin::GenerateFile::ShareDir /, '$plugin is passed to the template');
like($content, qr/Dist::Zilla $Dist::Zilla::VERSION/, '$zilla is passed to the template');
like($content, qr/Some-Other-Dist-2.0/, 'dist name can be fetched from the $plugin object');
like($content, qr/Le numéro de Maurice Richard est neuf./, 'arbitrary args are passed to the template');
like($content, qr/¡And hello 김도형 - Keedi Kim!/, 'encoding looks good (hi 김도형)');

cmp_deeply(
    $tzil->distmeta,
    superhashof({
        x_Dist_Zilla => superhashof({
            plugins => supersetof({
                class => 'Dist::Zilla::Plugin::GenerateFile::ShareDir',
                config => superhashof({
                    'Dist::Zilla::Plugin::GenerateFile::ShareDir' => {
                        dist => 'Some-Other-Dist',
                        encoding => 'UTF-8',
                        source_filename => 'template.txt',
                        destination_filename => 'data/useless_file.txt',
                        location => 'root',
                        phase => 'build',
                        numero => 'neuf',
                    },
                    'Dist::Zilla::Role::RepoFileInjector' => superhashof({
                        version => Dist::Zilla::Role::RepoFileInjector->VERSION,
                    }),
                }),
                name => 'GenerateFile::ShareDir',
                version => Dist::Zilla::Plugin::GenerateFile::ShareDir->VERSION,
            }),
        }),
    }),
    'config is properly included in metadata',
)
or diag 'got distmeta: ', explain $tzil->distmeta;

diag 'got log messages: ', explain $tzil->log_messages
    if not Test::Builder->new->is_passing;

done_testing;
