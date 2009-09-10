use inc::Module::Install;
include 'Module::AutoInstall';

name 'App-sync_cpantesters';
all_from 'lib/App/sync_cpantesters.pm';

auto_set_homepage;
auto_set_bugtracker;
auto_set_repository;

requires 'Getopt::Attribute';
requires 'HTML::FormatText';
requires 'HTML::TreeBuilder';
requires 'LWP::UserAgent::ProgressBar';
requires 'Web::Scraper';

test_requires 'Test::More' => '0.70';
extra_tests;

author_requires 'ShipIt';
author_requires 'ShipIt::Step::DistClean';
author_requires 'ShipIt::Step::DistTestExtra';
author_requires 'ShipIt::Step::Manifest';
author_requires 'ShipIt::Step::Twitter';
author_requires 'Test::Compile';
author_requires 'Test::Perl::Critic';
author_requires 'Test::Pod';
author_requires 'Test::Spelling';
author_requires 'Pod::Wordlist::hanekomu';
author_requires 'Test::Pod::Coverage';
# author_requires 'Test::Kwalitee';   # Attempt to free unreferenced scalar
author_requires 'Test::YAML::Meta';
author_requires 'Test::Portability::Files';
author_requires 'Test::Synopsis';

install_script glob('bin/*');

auto_install;
auto_include;
WriteAll;
