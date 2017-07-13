#!/usr/bin/env perl

use 5.010;
use strict;
use warnings;
use Fatal qw/open close chdir/;
use Getopt::Long;
use File::Basename;

my $usage = <<"END_USAGE";
Usage: $0 --input=<user input file> --template=<template.fa> [Options]
Required Parameters:
    --input FILE        a tab-delimited text file listing primer choosing regions, one per line: 
                        [template_ID] [target_start] [target_length] [product_size_min] [product_size_max]
    --template FILE     a FASTA file (recommend indexed with Samtools) of your template genome/transcriptome

Optional Parameters: Primer Design
    --region_type STR   SEQUENCE_TARGET; SEQUENCE_INCLUDED_REGION; FORCE_END
                        Default: [SEQUENCE_TARGET]
    --samtools STR      Your Samtools path: /path/to/samtools   
                        Default: [samtools] (Assume in your system PATH)
    --primer3bin STR    Your primer3_core path: /path/to/primer3_core
                        Default: [primer3_core] (Assume in your system PATH)
    --primer3setting STR
                        A Primer3 setting file. [STRONGLY RECOMMEND!]
                        Default: [] (Using all the default parameters in Primer3)
    --product_size_min INT
                        Lower limit of designed product sizes in bp. Default: [100]
    --product_size_max INT
                        Upper limit of designed product sizes in bp. Default: [1000]
                        

Optional Parameters: Primer Specificity Check
    --blastn STR        Your blastn (NCBI BLAST+) path: /path/to/blastn
                        Default: [blastn] (Assume in your system PATH)
    --blast_e_value FLOAT
                        The parameter e_value passed to blastn. Default: [30000]
    --blast_word_size INT
                        The parameter word_size passed to blastn. Default: [7]
    --blast_identity  FLOAT
                        The parameter perc_identity passed to blastn. Default: [60]
    --blast_max_hsps  INT
                        The parameter max_hsps passed to blastn. Default: [500]
    --checkingdb STR    The NCBI BLAST+ database of your background genome/transcriptome.
                        Default: the same as --template
    --checking_size_start INT
                        Lower limit of the checking amplicon size range in bp. Default: [50]
    --checking_size_stop INT
                        Upper limit of the checking amplicon size range in bp. Default: [5000]
    --primer_num_retain INT
                        The max number of primers for each site to return. It must be used together with 
                        --primer3setting and should not be larger than PRIMER_NUM_RETURN in the setting
                        file. Default: [10]
    --min_Tm_diff FLOAT 
                        The mininum melting temperature (in ℃) suggested to produce off-target amplicon.
                        Recommend to be at least 10℃ lower than PRIMER_MIN_TM in primer3 settings.
                        Default: [10]
    --use_3end          If turned on, primer pairs having at least one mismatch at the 3' end
                        position with templates would not be considered to produce off-target amplicon, even if
                        their melting temperatures are higher than [min_Tm]. Turn on this would find more
                        candidate primers, but might also have more false positives.
                        
Optional Parameters: Experimental Setting
    --conc_primer FLOAT
                        Concentration (nM) of primers. Default: [100]
    --conc_Na FLOAT     Concentration (mM) of Na+. Default: [0]
    --conc_K FLOAT      Concentration (mM) of K+. Default: [50]
    --conc_Tris FLOAT   Concentration (mM) of Tris. Default: [10]
    --conc_Mg           Concentration (mM) of Mg2+. Default: [1.5]
    --conc_dNTPs        Concentration (mM) of dNTPs. Default: [0.2]
                        
Optional Parameters: Output
    --outputdir STR     The output directory. Default: [./PrimerServerOutput]
    --debug             If turned on, print additional debug information. Default: [OFF]
    
Optional Parameters: System Configuration
    --num_cpu INT       The number of CPUs used to run NCBI BLAST+.
                        Default: 1
    --help              Print this help and exit
END_USAGE

my $help;
my $input;
my $samtools = "samtools";
my $primer3bin = "primer3_core";
my $primer3setting = "";
my $product_size_min = 100;
my $product_size_max = 1000;
my $template;
my $dir = "PrimerServerOutput";
my $checkingdb;
my $size_start = 50;
my $size_stop = 5000;
my $blastn = "blastn";
my $blast_e_value = 30000;
my $blast_word_size = 7;
my $blast_identity = 60;
my $blast_max_hsps = 500;
my $primer_conc = 100;    #nM  
my $Na          = 0;      #mM
my $K           = 50;     #mM
my $Tris        = 10;     #mM
my $Mg          = 1.5;    #mM  
my $dNTPs       = 0.2; #mM 
my $min_Tm_diff = 10;
my $detail;
my $use_3end;
my $retain = 10;
my $cpu = 1;
my $region_type = "SEQUENCE_TARGET";
my $debug;
my $report_last_5bp_in_3end;
GetOptions(
    'help'          =>  \$help,
    'input=s'       =>  \$input,
    'template=s'    =>  \$template,
    'samtools=s'    =>  \$samtools,
    'primer3bin=s'  =>  \$primer3bin,
    'primer3setting=s'=>\$primer3setting,
    'product_size_min=i'    =>  \$product_size_min,
    'product_size_max=i'    =>  \$product_size_max,
    'checkingdb=s'    =>  \$checkingdb,
    'checking_size_start=i' => \$size_start,
    'checking_size_stop=i' => \$size_stop,
    'num_cpu=i'     =>  \$cpu,
    'output_detail' => \$detail,
    'use_3end'      =>  \$use_3end,
    'primer_num_retain=i' => \$retain,
    'outputdir=s'   =>  \$dir,
    'region_type=s' =>  \$region_type,
    'blastn=s'      =>  \$blastn,
    'blast_e_value=f' =>  \$blast_e_value,
    'blast_word_size=i' => \$blast_word_size,
    'blast_identity=f' => \$blast_identity,
    'blast_max_hsps=i' => \$blast_max_hsps,
    'debug' =>  \$debug,
    'report_last_5bp_in_3end'   =>  \$report_last_5bp_in_3end,
    'conc_primer=f' =>  \$primer_conc,
    'conc_Na=f'     =>  \$Na,
    'conc_K=f'      =>  \$K,
    'conc_Tris=f'   =>  \$Tris,
    'conc_Mg=f'     =>  \$Mg,
    'conc_dNTPs=f'  =>  \$dNTPs,
    'min_Tm_diff=f' =>  \$min_Tm_diff,
);
if (!$checkingdb) {
    $checkingdb = $template;
}


if ($help or !$input or !$template) {
    print "$usage";
    exit(0);
}

####### Check Included Scripts #########
my $perl = $0;
my $check_link = `file $0`;
if ($check_link=~/symbolic link to/) {
    ($perl) = $check_link=~/symbolic link to `(.*)'/;
}
my $perl_dir = dirname $perl;
my $perl_base = basename $perl;
for my $script (qw/_run_primer3.pl _run_specificity_check.pl _run_final_selection.pl/) {
    if (!-e "$perl_dir/$script") {
        die "Cannot find script $script under $perl_dir\n";
    }
}


####### Check Tool Path #########
if (system("which $samtools >/dev/null 2>&1")!=0 && system("$samtools >/dev/null 2>&1")!=0) {   # Samtools path is error
    die "Can not find Samtools\n";
}
if (system("which $primer3bin >/dev/null 2>&1")!=0 && system("$primer3bin >/dev/null 2>&1")!=0) {   # Primer3 path is error
    die "Can not find Primer3\n";
}
if (system("which $blastn >/dev/null 2>&1")!=0 && system("$blastn >/dev/null 2>&1")!=0) {   # Blastn path is error
    die "Can not find Blastn\n";
}

####### Check query and db #########
if (!-e($input)) {
    die "Can not find file $input\n";
}
if (!-e($template)) {
    die "Can not find file $template\n";
}

####### Run primer3, generate [primer3output.txt] and [primer3output.simple.table.txt] #########
my $cmd = "perl $perl_dir/_run_primer3.pl --input=$input --db=$template --region_type=$region_type "
            ."--primer3bin=$primer3bin --samtools=$samtools --outputdir=$dir --product_size_min=$product_size_min --product_size_max=$product_size_max ";
if ($primer3setting) {
    $cmd .= " --primer3setting=$primer3setting";
}
my $status = system $cmd;
if ($status!=0) {
    exit(1);
}

####### Run Specificity Check, generate [specificity.check.result.txt] ##########
$cmd = "perl $perl_dir/_run_specificity_check.pl --input=$dir/primer3output.simple.table.txt --num_cpu=$cpu "
            ." --db='$checkingdb' --samtools=$samtools --outputdir=$dir --size_start=$size_start --size_stop=$size_stop "
            ." --blastn=$blastn --blast_e_value=$blast_e_value --blast_word_size=$blast_word_size "
            ." --blast_identity=$blast_identity --blast_max_hsps=$blast_max_hsps  --min_Tm_diff=$min_Tm_diff "
            ." --conc_primer=$primer_conc --conc_Na=$Na --conc_K=$K --conc_Tris=$Tris --conc_Mg=$Mg --conc_dNTPs=$dNTPs";
if ($use_3end) {
    $cmd .= " --use_3end";
}
if ($report_last_5bp_in_3end) {
    $cmd .= " --report_last_5bp_in_3end";
}
system $cmd;
$status = system $cmd;
if ($status!=0) {
    exit(1);
}


####### Retrieve Results, generate [primer.final.result.txt] ##########
$cmd = "perl $perl_dir/_run_final_selection.pl --primer3result=$dir/primer3output.txt --region_type=$region_type "
              ."--specificity=$dir/specificity.check.result.txt --retain=$retain --amplicon=$dir/specificity.check.result.amplicon "
              ."--outputdir=$dir";
if ($detail) {
    $cmd .= " --detail";
}
system $cmd;
$status = system $cmd;
if ($status!=0) {
    exit(1);
}


