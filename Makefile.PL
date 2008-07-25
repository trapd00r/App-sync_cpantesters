use inc::Module::Install;
include 'Module::AutoInstall';

name 'App-sync_cpantesters';
all_from 'lib/App/sync_cpantesters.pm';
perl_version '5.006';

requires 'Getopt::Attribute';
requires 'HTML::FormatText';
requires 'HTML::TreeBuilder';
requires 'LWP::UserAgent::ProgressBar';
requires 'Web::Scraper';

recommends 'Test::Pod';
recommends 'Test::Pod::Coverage';

test_requires 'Test::More' => '0.70';
test_requires 'Test::Compile';

install_script glob('bin/*');

auto_install;
auto_include;
WriteAll;
