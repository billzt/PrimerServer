#!/usr/bin/perl

use 5.010;
use strict;
use warnings;
use Fatal qw/open close chdir/;
use Getopt::Long;

my $usage = <<"END_USAGE";
usage: $0 --input=<user input table> --db=<db1> <db2> ... [Option]
Required:
--input     
--db 
Optional:
--pypy
--outputdir
--help      Print this help and exit
END_USAGE

my $help;
my $input;
my $db;
my $pypy = "pypy";
my $dir = ".";

GetOptions(
    'help'          =>  \$help,
    'input=s'       =>  \$input,
    'db=s'          =>  \$db,
    'pypy=s'        =>  \$pypy,
    'outputdir=s'   =>  \$dir,
);

if ($help or !$input or !$db) {
    print "$usage";
    exit(0);
}

####### Check Tool Path #########
if (system("which pypy >/dev/null 2>&1")!=0 && system("$pypy >/dev/null 2>&1")!=0) {   # Pypy path is error
    die "Can not find Pypy\n";
}

####### Check query and db #########
if (!-e($input)) {
    die "Can not find file $input\n";
}
if (!-e($db)) {
    die "Can not find file $db\n";
}

####### Generate MFEPrimer input and Run one by one #########
open my $in_fh, "<", $input;
open my $out_fh, ">", "$dir/specificity.check.result.txt";
mkdir "$dir/tmp.MFEPrimer" unless (-e "$dir/tmp.MFEPrimer");
while (<$in_fh>) {
    chomp;
    my ($id, $rank, @seqs) = split;
    open my $tmp_out_fh, ">", "$dir/tmp.MFEPrimer/$id.$rank.txt";
    for my $i (0..$#seqs) {
        print {$tmp_out_fh} ">$id.$rank.Primer$i\n$seqs[$i]\n";
    }
    close $tmp_out_fh;
    system "$pypy ../MFEprimer/MFEprimer.py -i $dir/tmp.MFEPrimer/$id.$rank.txt -d $db >$dir/tmp.MFEPrimer/$id.$rank.txt.out";
    
    my $hit_num_line = `grep 'potential PCR amplicon' $dir/tmp.MFEPrimer/$id.$rank.txt.out`;
    my ($hit_num) = $hit_num_line=~/Distribution of (\d+) potential PCR amplicon/;
    print {$out_fh} "$id\t$rank\t$hit_num\n";
    system "rm -f $dir/tmp.MFEPrimer/$id.$rank.txt";
}
close $in_fh;
close $out_fh;

