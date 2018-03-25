#!/usr/local/bin/perl -w
use strict;
use utf8;
use Getopt::Long;
use File::Spec;
use Excel::Writer::XLSX;

my $help = "usage: perl ISAstructured-summary.pl -i investigation_file.txt -i investigation_file.txt ... [-v]

-i investigation_file [required]

Specify one or more Investigation files (must be unzipped). Structured summaries
are output to an XLSX excel file named \"study_identifer.structured-summary.xlsx\",
where the study_identifer is parsed from the Investigation File.  

-v [optional]
Activates verbose mode.

";


# arguments and files
my $verbose = 0;
my @i_path;
my $sep = ' • ';


my %recognized_char = (
    "organism" => 1,
    "organism part" => 1,
    "cell line" => 1,
    "environment type" => 1,
    "geographical location" => 1
    );


GetOptions(
    "verbose" => \$verbose, # flag
    "i=s" => \@i_path
) or die "Bad options $!\n\n$help\n";

unless (@i_path) { die "\n\n$help\n"; }

foreach my $i_path ( @i_path ) {
    my @design_types;
    my @factor_types;
    my @meas_types;
    my @tech_types;
    my @characteristics;
    my $s_file;
    my $s_id; 
    

    my ($volume,$isa_folder,$i_file) = File::Spec->splitpath( $i_path );
    print STDERR "Reading vol:$volume | folder:$isa_folder | file:$i_file\n" if $verbose;
    
    
    unless ( $i_path ) { die "please provide the required arguments\n\n$help\n" }
    
    #open investigation file
    
    
    print STDERR "Parsing Investigation File $i_file.\n" if $verbose;
    
    
    open (INVEST, $i_path) or die "$! $i_path\n\n";
    my $temp;
    my @line;
    my $field;
    my $cell;
    while (<INVEST>) {
        chomp;
        @line = split(/\t/, $_);
        $field = shift @line;
        if ($field eq 'Study Design Type') {
            foreach $cell (@line) {
                $temp = &cleaner($cell);
                if ($temp ne "") { push @design_types, $temp }
            }
        } elsif ($field eq 'Study Factor Type') {
            foreach $cell (@line) {
                $temp = &cleaner($cell);
                if ($temp ne "") { push @factor_types, $temp }
            }
        } elsif ($field eq 'Study Assay Measurement Type') {
            foreach $cell (@line) {
                $temp = &cleaner($cell);
                if ($temp ne "") { push @meas_types, $temp }
            }
        } elsif ($field eq 'Study Assay Technology Type') {
            foreach $cell (@line) {
                $temp = &cleaner($cell);
                if ($temp ne "") { push @tech_types, $temp }
            }
        } elsif ($field eq 'Study File Name') {
            $s_file = &cleaner(shift @line);
        } elsif ($field eq 'Study Identifier') {
            $s_id = &cleaner(shift @line); 
            $s_id =~ s/^.*?\///;
        }
        
    }
    close INVEST;
    
    my $s_path = File::Spec->catfile( $isa_folder, $s_file);
    open (STUDY, $s_path) or die "$! $s_file\n\n";
    print STDERR "Parsing Study File $s_file.\n" if $verbose;
    
    my @cols;
    my @values;
    my $i = 1;
    my $k = 0;
    my @capture;
    while (<STUDY>) {
        chomp;
        if ($i == 1) {
            @cols = split(/\t/, $_);
            foreach $cell ( @cols ) {
                $temp = &cleaner($cell);
                if ($temp =~ /Characteristics\[(.*?)\]/) {
                    if ( $recognized_char{$1} ) { 
                        print STDERR "found sample characteristic \"$1\"\n" if $verbose;
                        push @capture, $k;
                    }
                }
                ++$k;
            }
            ++$i; next;
        }
        @values = split(/\t/, $_);
        foreach $k (@capture) {
            $temp = &cleaner($values[$k]);
			print STDERR if $temp =~ /GAZ/;
            push (@characteristics, $temp) unless $temp eq "";
        }
        $i++;
    }
    close STUDY;
    
    
    #OUTPUT
    print STDERR "Writing structured summary for ISA $s_id from $i_path\n" if $verbose;
    
    
    # Create a new Excel workbook
    my $workbook = Excel::Writer::XLSX->new( "$s_id.structured-summary.xlsx" );
    
    # Add a worksheet
    my $worksheet = $workbook->add_worksheet();
    
    # Write the content
    $worksheet->write( 'A1', "Design Type(s)" );
    $worksheet->write( 'B1', join( $sep, uniq(@design_types)) ); 
    $worksheet->write( 'A2', "Measurement Type(s)" );
    $worksheet->write( 'B2', join( $sep, uniq(@meas_types)) );
    $worksheet->write( 'A3', "Technology Type(s)" );
    $worksheet->write( 'B3', join( $sep, uniq(@tech_types)) );
    $worksheet->write( 'A4', "Factor Type(s)" );
    if ( @factor_types) { 
        $worksheet->write( 'B4', join( $sep, uniq(@factor_types)) );
    } else {
        print STDERR "no Factor Types for $s_id in file $i_path\n" if $verbose;
    }
    $worksheet->write( 'A5', "Sample Characteristic(s)" );
    if ( @characteristics ) {
        $worksheet->write( 'B5', join ( $sep, uniq(@characteristics)) );
    } else {
        print STDERR "no Sample Characteristics for $s_id in file $s_path\n" if $verbose;
    }

    print "\n" if $verbose;
}

 
exit;

sub cleaner {
    my $string = shift;
    if ($string) {
        $string =~ s/"//g;
        $string =~ s/^\s+|\s+$//g;
        return $string;
    } else {
        return "";
    }
}

sub uniq {
    my %seen;
    grep !$seen{$_}++, @_;
}


