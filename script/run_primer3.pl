#!/usr/bin/perl

use 5.010;
use strict;
use warnings;
use Fatal qw/open close chdir/;
use Getopt::Long;

my $usage = <<"END_USAGE";
usage: $0 --input=<user input file> --db=<template.fa> [Option]
Required:
--input     a tab-delimited text file listing primer choosing regions, one per line: 
            template_ID target_start    target_length   product_size_min    product_size_max
--db        
Optional:
--samtools  Your Samtools Path : [/path/to/samtools]
--primer3bin
--primer3setting
--outputdir
--help      Print this help and exit
END_USAGE

my $help;
my $input;
my $samtools = "samtools";
my $primer3bin = "primer3_core";
my $primer3setting = "";
my $db;
my $dir = ".";
GetOptions(
    'help'          =>  \$help,
    'input=s'       =>  \$input,
    'db=s'          =>  \$db,
    'samtools=s'    =>  \$samtools,
    'primer3bin=s'  =>  \$primer3bin,
    'primer3setting=s'=>\$primer3setting,
    'outputdir=s'   =>  \$dir,
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

####### Retrieve template sequence by samtools #########
my @samtools_regions;
my %samtools2region_data;
open my $input_fh, "<", $input;
while (<$input_fh>) {
    chomp;
    next if (/^#/);
    my @data = split;
    if (@data!=5) {
        die "Not 5 columns in line $_. Perhaps there is some input error\n";
    }
    my ($chr, $target_start, $target_length, $size_min, $size_max) = split;
    $target_start =~ s/,//g;
    my $retrieve_start = $target_start-$size_max>0 ? $target_start-$size_max : 1;
    my $retrieve_end = $target_start+$target_length+$size_max;
    push @samtools_regions, "$chr:$retrieve_start-$retrieve_end";
    $samtools2region_data{"$chr:$retrieve_start-$retrieve_end"} = [$chr, $target_start, $target_length, $size_min, $size_max];
}
close $input_fh;
system "$samtools faidx $db @samtools_regions >$dir/retrieve.tmp";

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
        my $relative_target_start = $target_start-$retrieve_start+1;
        print {$tmp_out_fh} <<"END_USAGE";
SEQUENCE_ID=$chr-$target_start-$target_length
SEQUENCE_TEMPLATE=$seq
SEQUENCE_TARGET=$relative_target_start,$target_length
PRIMER_PRODUCT_SIZE_RANGE=$size_min-$size_max
=
END_USAGE
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
    while (<$tmp_in_fh>) {
        chomp;
        my ($id) = /SEQUENCE_ID=(\S+)/;
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
system "rm -f $dir/*.tmp";