#!/usr/local/bin/perl -w
use strict;
use File::Fetch;
use HTTP::Tiny;
use Cwd;
use REST::Client;
use JSON::Parse ':all';

##########
# This script downloads to the working directory all of the ISA-tab files 
# associated with Sci. Data's Data Descriptors. It will skip downloading any
# files that are already present in the local directory. Download will fail for 
# all content types other than Data Descriptors. 
# A. Hufton, March 2018
##########


my $dir = getcwd;

# Call CrossRef to get a list of our publications, and some basic metadata
# This will only work up until we have >1000 publications, then some modification
# of the API call will be needed

my $client = REST::Client->new();
$client->addHeader('User-Agent', 'SciData; mailto:andrew.hufton@nature.com');
$client->GET("http://api.crossref.org/journals/2052-4463/works?rows=1000&select=DOI,published-online,alternative-id");

my $article_metadata = parse_json ( $client->responseContent() ); 

foreach my $article ( @{$article_metadata->{'message'}->{'items'}} ) {
    
    my $article_id = $article->{'alternative-id'}->[0];
    my $pub_year = $article->{'published-online'}->{'date-parts'}->[0]->[0];
    
    my $url = "http://www.nature.com/article-assets/npg/sdata/$pub_year/$article_id/isa-tab/$article_id-isa1.zip";
    
    print STDERR "Checking whether an ISAtab for article $article_id from year $pub_year exists.\n";
    
    if ( -f "$dir/$article_id-isa1.zip" ) {
        print STDERR "ISA tab already present in working directory. Skipping download.\n";
    } else {
    
        my $response = HTTP::Tiny->new->get($url);
        if ($response->{success}) {
            print STDERR "Does exist, fetching file.\n";
                
            # build a File::Fetch object
            my $ff = File::Fetch->new(uri => $url);
        
            #fetch the uri to cwd()
            my $where = $ff->fetch() or print STDERR $ff->error;
        } else {
            print STDERR "Does not exist or timeout.\n";
        }
    }
}

exit;