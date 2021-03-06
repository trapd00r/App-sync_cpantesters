use 5.006;
use warnings;
use strict;

package App::sync_cpantesters;
# ABSTRACT: Sync CPAN testers failure reports to local directories

use open qw(:utf8);
use Cwd 'abs_path';
use File::Find;
use File::Path;
use File::Spec;
use Getopt::Attribute;
use HTML::FormatText;
use HTML::TreeBuilder;
use LWP::UserAgent::ProgressBar;
use Pod::Usage;
use Web::Scraper;

sub usage ($;$$) {
    my ($message, $exitval, $verbose) = @_;

    # make sure there's exactly one newline;
    1 while chomp $message;
    $message .= "\n";
    $exitval ||= 1;
    $verbose ||= 2;
    pod2usage(
        {   -message => $message,
            -exitval => $exitval,
            -verbose => $verbose,
            -output  => \*STDERR
        }
    );
}

sub get {
    my $url      = shift;
    my $response = LWP::UserAgent::ProgressBar->new->get_with_progress($url);
    $response->is_success or die "couldn't get $url\n";
    $response->content;
}

sub run {
    our $uri : Getopt(uri|u=s);
    our $author : Getopt(author|a=s);
    our $base_dir : Getopt(dir|d=s);
    our $verbose : Getopt(verbose|v);
    our $ignore : Getopt(ignore|i=s);
    our $help : Getopt(help|h);
    pod2usage(-verbose => 2, -exitval => 0) if $help || Getopt::Attribute->error;
    usage "need --basedir\n" unless defined $base_dir;
    usage "can't have both --uri and --author\n"
      if defined($uri) && defined $author;
    $uri = sprintf 'http://cpantesters.perl.org/author/%s.html', $author
      if defined $author;
    usage "need --uri or --author\n" unless defined $uri;

    # make base_dir absolute
    $base_dir = abs_path($base_dir)
      unless File::Spec->file_name_is_absolute($base_dir);
    my $scraper = scraper {
        process '//div[contains(@class, "off")][.//td[@class="FAIL"]]', 'dist[]' => scraper {
            process '//h2/a[@name]',             name     => '@name';
            process '//tr/td[@class="FAIL"]/a', 'fail[]' => '@href';
        };
    };
    $verbose && print "Downloading $uri...\n";
    my $html = get($uri);
    $verbose && print "Scraping information...\n";
    my $result = $scraper->scrape(\$html);
    $verbose && print "Creating directory $base_dir...\n";
    mkpath($base_dir);
    my $formatter = HTML::FormatText->new(leftmargin => 0, rightmargin => 50);
    my %report;    # lookup hash to see which files and dirs should be there
    $verbose && print "Start iterating through results...\n";

    my @dist = @{ $result->{dist} || [] };
    if ($ignore) {
        @dist = grep { $_->{name} !~ /$ignore/o } @dist;
    }

    for my $dist (@dist) {
        ref $dist eq 'HASH' or die 'expected a HASH reference';
        $verbose && print "Processing results for $dist->{name}...\n";
        unless (exists $dist->{fail}) {
            $verbose && print "No failures, skipping.\n\n";
            next;
        }
        ref $dist->{fail} eq 'ARRAY'
          or die "expected 'fail' to be an ARRAY reference";
        (my $dir = $dist->{name}) =~ s/\s+/-/g;
        $dir = "$base_dir/$dir";
        $verbose && print "Creating directory $dir...\n";
        mkpath($dir);
        $report{dir}{$dir}++;
        for my $fail (@{ $dist->{fail} || [] }) {
            (my $id = $fail) =~ s!.*/!!;
            $verbose && print "Failure id $id\n";
            my $filename = "$dir/$id";
            if (-e $filename) {
                $verbose && print "File $filename exists, skipping.\n";
                $report{file}{$filename}++;
                next;
            }
            $verbose && print "Downloading $fail...\n";
            my $content = get($fail);
            open my $fh, '>', $filename
              or die "can't open $filename for writing: $!\n";
            print $fh $formatter->format(
                HTML::TreeBuilder->new_from_content($content));
            close $fh or die "can't close $filename: $!\n";
            $report{file}{$filename}++;
        }
        $verbose && print "\n";
    }
    $verbose && print "Deleting files other than the current failure reports...\n";
    find(
        sub {
            if (-d) {
                return if /^\.+$/;
                return if $report{dir}{$File::Find::name};
                $verbose && print "Deleting directory $File::Find::name\n";
                rmtree($File::Find::name);
                $File::Find::prune = 1;
            } elsif (-f) {
                return if $report{file}{$File::Find::name};
                $verbose && print "Deleting file $File::Find::name\n";
                unlink $File::Find::name;
            }
        },
        $base_dir
    );
}
1;

=head1 SYNOPSIS

    # sync_cpantesters -a MARCEL -d ~/dev/cpan-testers

=head1 DESCRIPTION

CPAN testers provide a valuable service. The reports are available on the Web
- for example, for CPAN ID C<MARCEL>, the reports are at
L<http://cpantesters.perl.org/author/MARCEL.html>. I don't like to read them
in the browser and click on each individual failure report. I also don't look
at the success reports. I'd rather download the failure reports and read them
in my favorite editor, vim. I want to be able to run this program repeatedly
and only download new failure reports, as well as delete old ones that no
longer appear in the master list - probably because a new version of the
distribution in question was uploaded.

If you are in the same position, then this program might be for you.

You need to pass a base directory using the C<--dir> options. For each
distribution for which there are failure reports, a directory is created. Each
failure report is stored in a file within that subdirectory. The HTML is
converted to plain text. For example, at one point in time, I ran the program
using:

    sync_cpantesters -a MARCEL -d reports

and the directory structure created looked like this:

    reports/Aspect-0.12/449224
    reports/Attribute-Memoize-0.01/39824
    reports/Attribute-Memoize-0.01/71010
    reports/Attribute-Overload-0.04/700557
    reports/Attribute-TieClasses-0.03/700575
    reports/Attribute-Util-1.02/455076
    reports/Attribute-Util-1.02/475237
    reports/Attribute-Util-1.02/477578
    reports/Attribute-Util-1.02/485231
    reports/Attribute-Util-1.02/489218
    ...

=head1 COMMAND-LINE OPTIONS

=over 4

=item C<--author> <cpanid>, C<-a> <cpanid>

The CPAN ID for which you want to download CPAN testers results. In my case,
this id is C<MARCEL>.

You have to use exactly one of C<--author> or C<--uri>.

=item C<--uri> <uri>, C<-u> <uri>

The URI from which to download the CPAN testers results. It needs to be in the
same format as, say, L<http://cpantesters.perl.org/author/MARCEL.html>. You
might want to use this option if you've already downloaded the relevant file;
in this case, use a C<file://> URI.

You have to use exactly one of C<--author> or C<--uri>.

=item C<--dir> <dir>, C<-d> <dir>

The directory you want to download the reports to. This can be a relative or
absolute path. This argument is mandatory.

=item C<--ignore> <regex>, C<-i> <regex>

If this argument is given, then every distribution whose name matches this
regular expression is ignored. You might use this when you have deprecated
distributions that you don't care about anymore, but the reports are still
there.

=item C<--verbose>, C<-v>

Be more verbose.

=item C<--help>, C<-h>

Show this documentation.

=back

=function run

The main function, which is called by the C<sync_cpantesters> program.

=function usage

Displays the program's usage information.

=function get

Takes a URL, downloads and returns the contents. A progress bar is displayed
during the download.

