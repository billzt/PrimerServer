#!/usr/bin/env perl

use 5.010;
use strict;
use warnings;
use Fatal qw/open close chdir mkdir/;
use Getopt::Long;

my $usage = <<"END_USAGE";
usage: $0 --input=<user input file> --db=<template.fa> [Option]
Required:
--input     a tab-delimited text file listing primer choosing regions, one per line: 
            template_ID target_start    target_length   [product_size_min]    [product_size_max]
--db        
Optional:
--region_type SEQUENCE_TARGET; SEQUENCE_INCLUDED_REGION; FORCE_END
--samtools
--primer3bin
--primer3setting
--outputdir
--product_size_min
--product_size_max
--debug
--help      Print this help and exit
END_USAGE

my $help;
my $input;
my $samtools = "samtools";
my $primer3bin = "primer3_core";
my $primer3setting = "";
my $db;
my $dir = "PrimerServerOutput";
my $region_type = "SEQUENCE_TARGET";
my $product_size_min = 100;
my $product_size_max = 1000;
my $debug;
GetOptions(
    'help'          =>  \$help,
    'input=s'       =>  \$input,
    'db=s'          =>  \$db,
    'samtools=s'    =>  \$samtools,
    'primer3bin=s'  =>  \$primer3bin,
    'primer3setting=s'=>\$primer3setting,
    'outputdir=s'   =>  \$dir,
    'region_type=s' =>  \$region_type,
    'product_size_min=i'    =>  \$product_size_min,
    'product_size_max=i'    =>  \$product_size_max,
    'debug' =>  \$debug,
);

if ($help or !$input or !$db) {
    print "$usage";
    exit(0);
}


####### Check Tool Path #########
if (system("which $samtools >/dev/null 2>&1")!=0 && system("$samtools >/dev/null 2>&1")!=0) {   # Samtools path is error
    die "Can not find Samtools\n";
}
if (system("which $primer3bin >/dev/null 2>&1")!=0 && system("$primer3bin >/dev/null 2>&1")!=0) {   # Primer3 path is error
    die "Can not find Primer3\n";
}

####### Check query and db #########
if (!-e($input)) {
    die "Can not find file $input\n";
}
if (!-e($db)) {
    die "Can not find file $db\n";
}

####### Make the working directory #########
if (!-e($dir)) {
    mkdir $dir;
}

####### Retrieve template sequence by samtools #########
my %samtools2region_data;
open my $input_fh, "<", $input;
open my $tmp_out_fh, ">", "$dir/region.list.tmp";
while (<$input_fh>) {
    chomp;
    next if (/^#/);
    my ($chr, $target_start, $target_length, $size_min, $size_max) = split;
    if (!$target_start && !$target_length) {    # If user only gives an ID, then use the whole template. (qRT-PCR)
        $target_start = 1;
        $target_length = `awk '\$1=="$chr"' $db.fai | cut -f 2`;
        chomp($target_length);
    }
    elsif ($target_start && !$target_length) {  # If user only gives an ID and a position, then set the target length as 1. (such as SNP)
        $target_length = 1;
    }
    if ($target_length>1000000) {
        die "Error: The target region length in template is too long: $chr: $target_length bp\n";
    }
    $target_start =~ s/,//g;
    if (!$size_min) {
        $size_min = $product_size_min;
    }
    if (!$size_max) {
        $size_max = $product_size_max;
    }
    my $retrieve_start = $target_start-$size_max>0 ? $target_start-$size_max : 1; # Such retrieve region is enough for all the three region types
    my $retrieve_end = $target_start+$target_length+$size_max;
    print {$tmp_out_fh} "$chr:$retrieve_start-$retrieve_end\n";
    $samtools2region_data{"$chr:$retrieve_start-$retrieve_end"} = [$chr, $target_start, $target_length, $size_min, $size_max];
}
close $input_fh;
close $tmp_out_fh;
system "xargs --arg-file=$dir/region.list.tmp $samtools faidx $db >$dir/retrieve.tmp";


####### Generate User Input #########
{
    local $/ = ">";
    open my $tmp_in_fh, "<", "$dir/retrieve.tmp";
    open my $tmp_out_fh, ">", "$dir/primer3input.tmp";
    while (<$tmp_in_fh>) {
        chomp;
        next unless ($_);
        my ($id, @seqs) = split;
        my $seq = join '', @seqs;
        my ($chr, $target_start, $target_length, $size_min, $size_max) = @{$samtools2region_data{$id}};
        my ($retrieve_start) = $id=~/\:(\d+)-/;
        my $relative_target_start = $target_start-$retrieve_start;
        
        ### SEQUENCE_TARGET
        if ($region_type eq "SEQUENCE_TARGET") {
            print {$tmp_out_fh} <<"END_USAGE";
SEQUENCE_ID=$chr-$target_start-$target_length
SEQUENCE_TEMPLATE=$seq
PRIMER_PRODUCT_SIZE_RANGE=$size_min-$size_max
SEQUENCE_TARGET=$relative_target_start,$target_length
=
END_USAGE
        }
        
        elsif ($region_type eq "SEQUENCE_INCLUDED_REGION") {
            print {$tmp_out_fh} <<"END_USAGE";
SEQUENCE_ID=$chr-$target_start-$target_length
SEQUENCE_TEMPLATE=$seq
PRIMER_PRODUCT_SIZE_RANGE=$size_min-$size_max
SEQUENCE_INCLUDED_REGION=$relative_target_start,$target_length
=
END_USAGE
        }
        elsif ($region_type eq "FORCE_END") {
            print {$tmp_out_fh} <<"END_USAGE";
SEQUENCE_ID=$chr-$target_start-$target_length-LEFT
SEQUENCE_TEMPLATE=$seq
PRIMER_PRODUCT_SIZE_RANGE=$size_min-$size_max
SEQUENCE_FORCE_LEFT_END=$relative_target_start
PRIMER_MIN_LEFT_THREE_PRIME_DISTANCE=-1
PRIMER_MIN_RIGHT_THREE_PRIME_DISTANCE=3
=
SEQUENCE_ID=$chr-$target_start-$target_length-RIGHT
SEQUENCE_TEMPLATE=$seq
PRIMER_PRODUCT_SIZE_RANGE=$size_min-$size_max
SEQUENCE_FORCE_RIGHT_END=$relative_target_start
PRIMER_MIN_RIGHT_THREE_PRIME_DISTANCE=-1
PRIMER_MIN_LEFT_THREE_PRIME_DISTANCE=3
=
END_USAGE
        }
    }
    close $tmp_in_fh;
    close $tmp_out_fh;
}

####### Run Primer3 #########
if ($primer3setting) {
    system "$primer3bin -p3_settings_file=$primer3setting $dir/primer3input.tmp >$dir/primer3output.txt";
}
else {
    system "$primer3bin $dir/primer3input.tmp >$dir/primer3output.txt";
}

####### Analysis Primer3 Result #########
{
    local $/ = "\n=\n";
    open my $tmp_in_fh, "<", "$dir/primer3output.txt";
    open my $simple_out_fh, ">", "$dir/primer3output.simple.table.txt";
    print {$simple_out_fh} "#Site_ID\tPrimer_Rank\tPrimer_Seq_Left\tPrimer_Seq_Right\n";
    while (<$tmp_in_fh>) {
        chomp;
        my ($id) = /SEQUENCE_ID=(\S+)/;
        my ($error) = /PRIMER_ERROR=(.*)/;
        if ($error) {       # There must be some error in primer design
            die "Error happend in primer design: $error\n";
        }
        my ($primer_num) = /PRIMER_PAIR_NUM_RETURNED=(\S+)/;
        if ($primer_num==0) {
            1;
        }
        else {
            for my $i (0..($primer_num-1)) {
                my ($seq_F) = /PRIMER_LEFT_ $i _SEQUENCE=(\S+)/x;
                my ($seq_R) = /PRIMER_RIGHT_ $i _SEQUENCE=(\S+)/x;
                print {$simple_out_fh} "$id\t$i\t$seq_F\t$seq_R\n";
            }
        }
    }
    close $simple_out_fh;
    close $tmp_in_fh;
}

####### Remove tmp files #########
if (!$debug) {
    system "rm -f $dir/*.tmp";
}
