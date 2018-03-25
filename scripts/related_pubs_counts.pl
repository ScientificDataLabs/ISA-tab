#!/usr/local/bin/perl -w
use strict;
use Archive::Zip;
use Cwd;
use Carp;
use File::Spec;
use REST::Client;
use JSON::Parse ':all';
binmode(STDOUT, ":utf8");

my $client = REST::Client->new();
my $dir = getcwd;
my $DD_DOI = '';

opendir (DIR, $dir) or die $!;
my @dir = readdir DIR;
print STDERR "running related publication analysis using all zip files in the current folder...\n";

print "Related article title\tJournal\tDOI\tData Descriptor title\tData Descriptor DOI\tData Descriptor year\tData Descriptor month\n";

foreach my $item (@dir) {
	if ( $item =~ /zip$/ ) {
		
		my $DD_title; 
		my $DD_year;
		my $DD_month;
		
		# Read investigation file
		print STDERR "opening $item and $dir\n";
		&unzip($item, "i_Investigation.txt", $dir);
		open (IFILE, "i_Investigation.txt") or die;
		
		while (<IFILE>) {
			chomp;
			my @line = split(/\t/, $_);
			my $field = shift @line;
			if ($field eq 'Study Identifier') {
				$DD_DOI = &ISAcleaner($line[0]);
				last if $DD_DOI eq '10.1038/sdata.2017.51'; 
				
				# get metadata for the Data Descriptor
                $client->GET("http://api.crossref.org/works/$DD_DOI");
                my $article_metadata = parse_json ( $client->responseContent() ); 
                $DD_title = &CrossREFcleaner($article_metadata->{'message'}->{'title'}->[0]);
                $DD_year = &CrossREFcleaner($article_metadata->{'message'}->{'issued'}->{'date-parts'}->[0]->[0]);
                $DD_month = &CrossREFcleaner($article_metadata->{'message'}->{'issued'}->{'date-parts'}->[0]->[1]);
			}
			if ($field eq 'Study Publication DOI') {
				foreach my $cell (@line) {
					my $temp = &ISAcleaner($cell);
					unless ($temp eq "" ) {
						$temp =~ s/^doi://;
						next unless ( $temp =~ /^10\./ );
						#ok, I have a related article DOI, get metadata about the related article
						$client->GET("http://api.crossref.org/works/$temp");
						my $article_metadata = parse_json ( $client->responseContent() ); 
						my $title = &CrossREFcleaner($article_metadata->{'message'}->{'title'}->[0]);
						my $journal = &CrossREFcleaner($article_metadata->{'message'}->{'container-title'}->[0]);
						
						print "$title\t$journal\t$temp\t$DD_title\t$DD_DOI\t$DD_year\t$DD_month\n";
					}
				}
				last;
			}
		}
		close IFILE;
	}
}
closedir DIR;

exit;


sub unzip {
    my ($archive, $want, $dir) = @_;
	my $path_in = File::Spec->catfile( $dir, $archive);
	my $path_out = File::Spec->catfile( $dir, $want);
    my $zip = Archive::Zip->new($path_in);
    foreach my $file ($zip->members) {
        next unless ($file->fileName eq $want);
        $file->extractToFileNamed($path_out);
    }
	croak "There was a problem extracting $want from $archive" unless (-e $path_out);
    return 1;
}

sub ISAcleaner {
    my $string = shift;
    if ($string) {
        $string =~ s/"//g;
        $string =~ s/\n//g;
        $string =~ s/^\s+|\s+$//g;
        return $string;
    } else {
        return "";
    }
}

sub CrossREFcleaner {
    my $string = shift;
    if ($string) {
        $string =~ s/\n//g;
        $string =~ s/^\s+|\s+$//g;
        $string =~ s/\h+/ /g;
        return $string;
    } else {
        return "";
    }
}
