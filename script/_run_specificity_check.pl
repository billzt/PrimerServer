#!/usr/bin/env perl

use 5.010;
use strict;
use warnings;
use Fatal qw/open close chdir/;
use Getopt::Long;
use List::Util qw/max min/;

my $usage = <<"END_USAGE";
usage: $0 --input=<user input table> --db=<db> [Option]
Required:
--input     
--db 
Optional:
--num_cpu
--size_start
--size_stop
--outputdir
--use_3end
--samtools
--blastn
--blast_e_value
--blast_word_size
--blast_identity
--blast_max_hsps
--conc_primer
--conc_Na
--conc_K
--conc_Tris
--conc_Mg
--conc_dNTPs
--min_Tm_diff
--help      Print this help and exit
END_USAGE

my $help;
my $input;
my $db;
my $primer_conc = 100;    #nM  
my $Na          = 0;      #mM
my $K           = 50;     #mM
my $Tris        = 10;     #mM
my $Mg          = 1.5;    #mM  
my $dNTPs       = 0.2; #mM 
my $min_Tm_diff = 10;
my $dir = ".";
my $size_start = 70;
my $size_stop = 1000;
my $detail;
my $use_3end;
my $cpu = 1;
my $samtools = "samtools";
my $blastn = "blastn";
my $blast_e_value = 30000;
my $blast_word_size = 7;
my $blast_identity = 60;
my $blast_max_hsps = 500;

GetOptions(
    'help'          =>  \$help,
    'samtools=s'    =>  \$samtools,
    'input=s'       =>  \$input,
    'db=s'          =>  \$db,
    'outputdir=s'   =>  \$dir,
    'size_start=i'  =>  \$size_start,
    'size_stop=i'   =>  \$size_stop,
    'detail'        =>  \$detail,
    'use_3end'      =>  \$use_3end,
    'num_cpu=i'     =>  \$cpu,
    'conc_primer=f' =>  \$primer_conc,
    'conc_Na=f'     =>  \$Na,
    'conc_K=f'      =>  \$K,
    'conc_Tris=f'   =>  \$Tris,
    'conc_Mg=f'     =>  \$Mg,
    'conc_dNTPs=f'  =>  \$dNTPs,
    'min_Tm_diff=f' =>  \$min_Tm_diff,
    'blastn=s'      =>  \$blastn,
    'blast_e_value=f' =>  \$blast_e_value,
    'blast_word_size=i' => \$blast_word_size,
    'blast_identity=f' => \$blast_identity,
    'blast_max_hsps=i' => \$blast_max_hsps
);

if ($help or !$input or !$db) {
    print "$usage";
    exit(0);
}

####### Check Tool Path #########
if (system("which $samtools >/dev/null 2>&1")!=0 && system("$samtools >/dev/null 2>&1")!=0) {   # Samtools path is error
    die "Can not find Samtools\n";
}
if (system("which $blastn >/dev/null 2>&1")!=0 && system("$blastn >/dev/null 2>&1")!=0) {   # Blastn path is error
    die "Can not find Blastn\n";
}

####### Generate  input files  #########
open my $in_fh, "<", $input;
my $out_fh;
mkdir "$dir" if (!-e $dir);
mkdir "$dir/tmp.specificity.check";
mkdir "$dir/result.specificity.check" if (!-e "$dir/result.specificity.check"); # Used to store pretty formatted alignments

my %primer_seq_for;
my @ids;    # Only used to keep order of site id;
my @run_array;
my %primer2group; 
open my $tmp_out_fh, ">", "$dir/tmp.specificity.check/primer.query.fa";
while (<$in_fh>) {
    chomp;
    next if (/^#/);
    my ($id, $rank, @seqs) = split;
    for my $i (0..$#seqs) {
        print {$tmp_out_fh} ">$id.$rank.Primer$i\n$seqs[$i]\n";
        $primer2group{"$id.$rank.Primer$i"} = "$id.$rank";
    }
    push @ids, $id if(!($id~~@ids));
    $primer_seq_for{$id}{$rank} = [@seqs];
    push @run_array, [$id, $rank];
}
close $in_fh;
close $tmp_out_fh;


####### Run BLAST #########
my $blastcmd = "$blastn -task blastn-short -query $dir/tmp.specificity.check/primer.query.fa -db $db -evalue $blast_e_value "
                ." -word_size $blast_word_size -perc_identity $blast_identity -dust no -ungapped -reward 1 -penalty -1 "
                ." -max_hsps $blast_identity -outfmt '6 qseqid qstart qend sseqid sstart send sstrand' "
                ." -out $dir/tmp.specificity.check/primer.query.fa.out -num_threads $cpu";
system $blastcmd;

####### Filter BLAST Results by Prodct Sizes #########
my %blastdata;
open $in_fh, "<", "$dir/tmp.specificity.check/primer.query.fa.out";
while (<$in_fh>) {
    chomp;
    my ($query, $qs, $qe, $target, $ts, $te, $strand) = split;
    my $group = $primer2group{$query};
    if ($strand eq 'plus') {
        $blastdata{$group}{$target}{$ts} = [$te, $strand, $query, $qs, $qe];
    }
    else {
        $blastdata{$group}{$target}{$te} = [$ts, $strand, $query, $qs, $qe];
    }
}
close $in_fh;
open $out_fh, ">", "$dir/tmp.specificity.check/primer.query.fa.out.filterlength";
for my $group (keys %blastdata) {
    for my $target (keys %{$blastdata{$group}}) {
        my @target_starts = sort {$a<=>$b} keys %{ $blastdata{$group}{$target} };
        for my $i (0..$#target_starts-1) {
            my $ts = $target_starts[$i];
            my ($te, $strand, $query, $qs, $qe) = @{$blastdata{$group}{$target}{$ts}};
            for my $j ($i+1..$#target_starts) {
                my $next_ts = $target_starts[$j];
                my ($next_te, $next_strand, $next_query, $next_qs, $next_qe) = @{$blastdata{$group}{$target}{$next_ts}};
                my $size = $next_te-$ts+1;
                next if ($size<$size_start);
                last if ($size>$size_stop);
                if ($strand eq 'plus' && $next_strand eq 'minus') {
                    print {$out_fh} "$target\t$ts\t$te\t$next_ts\t$next_te\t$size\t$query\t$qs\t$qe\t$next_query\t$next_qs\t$next_qe\n";
                }
            }
        }
    }
}

close $out_fh;

####### Run Tm and 3'end mismatch check  #########
############################################################
#### FUNCTIONS AND TABLES
############################################################

# SantaLucia & Hicks (2004), Annu. Rev. Biophys. Biomol. Struct 33: 415-440
# delta H (Enthalpy)(kcal/mol) and delta S (Entropy)(eu) coefficients

my %DNA_NN_table = (
    'init'        => [0.2, -5.7], 
    'init_A/T'    => [2.2, 6.9], 
    'init_G/C'    => [0, 0], 
    'init_oneG/C' => [0, 0], 
    'init_allA/T' => [0, 0], 
    'init_5T/A'   => [0, 0],
    'sym'         => [0, -1.4],
    'AA/TT'       => [-7.6, -21.3], 
    'AT/TA'       => [-7.2, -20.4], 
    'TA/AT'       => [-7.2, -20.4], 
    'CA/GT'       => [-8.5, -22.7], 
    'GT/CA'       => [-8.4, -22.4], 
    'CT/GA'       => [-7.8, -21.0], 
    'GA/CT'       => [-8.2, -22.2], 
    'CG/GC'       => [-10.6, -27.2], 
    'GC/CG'       => [-9.8, -24.4], 
    'GG/CC'       => [-8.0, -19.0]
);

# Internal mismatch and inosine table (DNA) 
# Allawi & SantaLucia (1997), Biochemistry 36: 10581-10594 
# Allawi & SantaLucia (1998), Biochemistry 37: 9435-9444 
# Allawi & SantaLucia (1998), Biochemistry 37: 2170-2179 
# Allawi & SantaLucia (1998), Nucl Acids Res 26: 2694-2701 
# Peyret et al. (1999), Biochemistry 38: 3468-3477                  
my %DNA_IMM_table = ( 
    # Allawi & SantaLucia (1997), Biochemistry 36: 10581-10594  http://pubs.acs.org/doi/pdf/10.1021/bi962590c
    'AG/TT'=> [1.0, 0.9], 'AT/TG'=> [-2.5, -8.3], 'CG/GT'=> [-4.1, -11.7],           
    'CT/GG'=> [-2.8, -8.0], 'GG/CT'=> [3.3, 10.4], 'GG/TT'=> [5.8, 16.3], 
    'GT/CG'=> [-4.4, -12.3], 'GT/TG'=> [4.1, 9.5], 'TG/AT'=> [-0.1, -1.7], 
    'TG/GT'=> [-1.4, -6.2], 'TT/AG'=> [-1.3, -5.3],
        
    'AA/TG'=> [-0.6, -2.3], 
    'AG/TA'=> [-0.7, -2.3], 'CA/GG'=> [-0.7, -2.3], 'CG/GA'=> [-4.0, -13.2], 
    'GA/CG'=> [-0.6, -1.0], 'GG/CA'=> [0.5, 3.2], 'TA/AG'=> [0.7, 0.7], 
    'TG/AA'=> [3.0, 7.4],
        
     # Allawi & SantaLucia (1998), Nucl Acids Res 26: 2694-2701 
    'AC/TT'=> [0.7, 0.2], 'AT/TC'=> [-1.2, -6.2], 'CC/GT'=> [-0.8, -4.5],                
    'CT/GC'=> [-1.5, -6.1], 'GC/CT'=> [2.3, 5.4], 'GT/CC'=> [5.2, 13.5], 
    'TC/AT'=> [1.2, 0.7], 'TT/AC'=> [1.0, 0.7],
        
    # Allawi & SantaLucia (1998), Biochemistry 37: 9435-9444  http://pubs.acs.org/doi/pdf/10.1021/bi9803729 
    'AA/TC'=> [2.3, 4.6], 'AC/TA'=> [5.3, 14.6], 'CA/GC'=> [1.9, 3.7],                   
    'CC/GA'=> [0.6, -0.6], 'GA/CC'=> [5.2, 14.2], 'GC/CA'=> [-0.7, -3.8], 
    'TA/AC'=> [3.4, 8.0], 'TC/AA'=> [7.6, 20.2],
        
    # Peyret et al. (1999), Biochemistry 38: 3468-3477 
    'AA/TA'=> [1.2, 1.7], 'CA/GA'=> [-0.9, -4.2], 'GA/CA'=> [-2.9, -9.8],             
    'TA/AA'=> [4.7, 12.9], 'AC/TC'=> [0.0, -4.4], 'CC/GC'=> [-1.5, -7.2], 
    'GC/CC'=> [3.6, 8.9], 'TC/AC'=> [6.1, 16.4], 'AG/TG'=> [-3.1, -9.5], 
    'CG/GG'=> [-4.9, -15.3], 'GG/CG'=> [-6.0, -15.8], 'TG/AG'=> [1.6, 3.6], 
    'AT/TT'=> [-2.7, -10.8], 'CT/GT'=> [-5.0, -15.8], 'GT/CT'=> [-2.2, -8.4], 
    'TT/AT'=> [0.2, -1.5]
);

# Terminal mismatch table (DNA) 
# SantaLucia & Peyret (2001) Patent Application WO 01/94611 
my %DNA_TMM_table = ( 
    'AA/TA'=> [-3.1, -7.8],  'TA/AA'=> [-2.5, -6.3],
    'CA/GA'=> [-4.3, -10.7], 'GA/CA'=> [-8.0, -22.5], 
    'AC/TC'=> [-0.1, 0.5],   'TC/AC'=> [-0.7, -1.3],
    'CC/GC'=> [-2.1, -5.1],  'GC/CC'=> [-3.9, -10.6], 
    'AG/TG'=> [-1.1, -2.1],  'TG/AG'=> [-1.1, -2.7],
    'CG/GG'=> [-3.8, -9.5],  'GG/CG'=> [-0.7, -19.2], 
    'AT/TT'=> [-2.4, -6.5], 'TT/AT'=> [-3.2, -8.9],
    'CT/GT'=> [-6.1, -16.9], 'GT/CT'=> [-7.4, -21.2], 
    'AA/TC'=> [-1.6, -4.0], 'AC/TA'=> [-1.8, -3.8], 'CA/GC'=> [-2.6, -5.9], 
    'CC/GA'=> [-2.7, -6.0], 'GA/CC'=> [-5.0, -13.8], 'GC/CA'=> [-3.2, -7.1], 
    'TA/AC'=> [-2.3, -5.9], 'TC/AA'=> [-2.7, -7.0], 
    'AC/TT'=> [-0.9, -1.7], 'AT/TC'=> [-2.3, -6.3], 'CC/GT'=> [-3.2, -8.0], 
    'CT/GC'=> [-3.9, -10.6], 'GC/CT'=> [-4.9, -13.5], 'GT/CC'=> [-3.0, -7.8], 
    'TC/AT'=> [-2.5, -6.3], 'TT/AC'=> [-0.7, -1.2], 
    'AA/TG'=> [-1.9, -4.4], 'AG/TA'=> [-2.5, -5.9], 'CA/GG'=> [-3.9, -9.6], 
    'CG/GA'=> [-6.0, -15.5], 'GA/CG'=> [-4.3, -11.1], ' GG/CA'=> [-4.6, -11.4], 
    'TA/AG'=> [-2.0, -4.7], 'TG/AA'=> [-2.4, -5.8], 
    'AG/TT'=> [-3.2, -8.7], 'AT/TG'=> [-3.5, -9.4], 'CG/GT'=> [-3.8, -9.0], 
    'CT/GG'=> [-6.6, -18.7], 'GG/CT'=> [-5.7, -15.9], 'GT/CG'=> [-5.9, -16.1], 
    'TG/AT'=> [-3.9, -10.5], 'TT/AG'=> [-3.6, -9.8]
);

#### DELTA S ION CORRECTION FUNCTION
    # Correction for deltaS(Entropy correction) : 0.368 x (N-1) x ln[Na+]
    # Reference: (SantaLucia (1998), Proc Natl Acad Sci USA 95: 1460-1465)    http://www.pnas.org/content/95/4/1460.full.pdf+html
    # Provide Millimolar(mmol/L) concentrations for Na, K, Tris, Mg and dNTPs
    # Von Ahsen et al. (2001, Clin Chem 47: 1956-1961)    http://www.clinchem.org/content/47/11/1956.full
    # [Na_eq] = [Na+] + [K+] + [Tris]/2 + 120*([Mg2+] - [dNTPs])^0.5 
    # If [dNTPs] >= [Mg2+]: [Na_eq] = [Na+] + [K+] + [Tris]/2

    # effect on entropy by salt correction; von Ahsen et al 1999
        # s+=0.368 * (strlen(c)-1)* log(salt_effect)

sub ion_correction {
    my ($Na, $K, $Tris, $Mg, $dNTPs, $seq_len) = @_;
    my $correction_factor  = 0;
    my $Na_eq_mmol;
    if ($dNTPs>=$Mg) {
        $Na_eq_mmol  =  $Na + $K + ($Tris/2);
    }
    else {
        $Na_eq_mmol  = $Na + $K + ($Tris/2) + 120*sqrt($Mg-$dNTPs);
    }
    my $Na_eq_mol = $Na_eq_mmol/1000;
    $correction_factor  =  0.368*($seq_len-1)*log($Na_eq_mol);
    return $correction_factor;
}

#### FUNCTION TO CALCULATE NN TERMODYNAMICS BASED MELTING TEMPERATURE(TM)
    # Calculates the Tm using the nearest neighbor thermodynamics
    # Arguments:
        # -seq        : The primer sequence           (5'->3' direction)
        # -compl_seq  : The complementary sequence    (3'->5' direction!!!!!) 
        # -primer_conc    : Concentration of the primer [nM]. Template strand which concentration is typically very low 
        # and may be ignored and so not included in this function.
        # -Na, K, Tris, Mg, dNTPs : Concentration of the respective ions [mM]. If any of K, Tris, Mg and dNTPS is 
        # non-zero, a 'sodium-equivalent' concentration is calculated and used for salt correction (von Ahsen et al., 2001).
        # -ion_corr   : See method 'Tm_GC'. Default = 1. (0 means no salt correction). 

sub NN_Tm {
    my ($seq, $compl_seq, $primer_conc, $Na, $K, $Tris, $Mg, $dNTPs, $ion_corr) = @_;
    my $dH          = 0;   # dH stands for delta H
    my $dS          = 0;   # dS stands for delta S
    my $dH_index    = 0;   # dH_index stands for deta H_index in a table (here position 0)
    my $dS_index    = 1;   # dS_index stands for delta S_index in a table (here position 1)
    
    my @seq = split //, uc($seq);
    my @compl_seq = split //, uc($compl_seq);
    
    # General initiation value
    $dH += $DNA_NN_table{'init'}->[$dH_index];
    $dS += $DNA_NN_table{'init'}->[$dS_index];
    
    # delta H and delta S correction for  Duplex with no (allA/T) or at least one (oneG/C) GC pair coefficients 
        # need not be considered while using SantaLucia & Hicks (2004) model
    # delta H and delta S correction for 5' end being T need not be considered while using SantaLucia & Hicks (2004) model  
    # delta H and delta S correction for A/T terminal basepairs (for the original seq and not for the end trimmed temp_seq)
    #### CONSIDERS TERMINAL MISMATCHES WHILE COUNTING TERMINAL A/Ts 
    my $count_AT = 0;
    my $terminal = $seq[0].'/'.$compl_seq[0];
    if ($terminal eq 'A/T' or $terminal eq 'T/A') {
        $count_AT++;
    }
    $terminal = $seq[-1].'/'.$compl_seq[-1];
    if ($terminal eq 'A/T' or $terminal eq 'T/A') {
        $count_AT++;
    }
    $dH += $DNA_NN_table{'init_A/T'}->[$dH_index] * $count_AT;
    $dS += $DNA_NN_table{'init_A/T'}->[$dS_index] * $count_AT;
    

    for my $i (0..$#seq-1) {
        my $NN = $seq[$i].$seq[$i+1].'/'.$compl_seq[$i].$compl_seq[$i+1];
        my $reverse_NN = scalar(reverse($NN));
        if ($i==0) { # left terminal NN, need to be specially treated when mismatch
            if ($DNA_TMM_table{$reverse_NN}) {
                $dH += $DNA_TMM_table{$reverse_NN}->[$dH_index];
                $dS += $DNA_TMM_table{$reverse_NN}->[$dS_index];
            }
            elsif ($DNA_NN_table{$NN}) {
                $dH += $DNA_NN_table{$NN}->[$dH_index];
                $dS += $DNA_NN_table{$NN}->[$dS_index];
            }
            elsif ($DNA_NN_table{$reverse_NN}) {
                $dH += $DNA_NN_table{$reverse_NN}->[$dH_index];
                $dS += $DNA_NN_table{$reverse_NN}->[$dS_index];
            }
            else {
                #die "No dH and dS value for $NN in $seq/$compl_seq in rank $i\n";
                1;
            }
        }
        elsif ($i==$#seq-1) { # right terminal NN, need to be specially treated when mismatch
            if ($DNA_TMM_table{$NN}) {
                $dH += $DNA_TMM_table{$NN}->[$dH_index];
                $dS += $DNA_TMM_table{$NN}->[$dS_index];
            }
            elsif ($DNA_NN_table{$NN}) {
                $dH += $DNA_NN_table{$NN}->[$dH_index];
                $dS += $DNA_NN_table{$NN}->[$dS_index];
            }
            elsif ($DNA_NN_table{$reverse_NN}) {
                $dH += $DNA_NN_table{$reverse_NN}->[$dH_index];
                $dS += $DNA_NN_table{$reverse_NN}->[$dS_index];
            }
            else {
                #die "No dH and dS value for $NN in $seq/$compl_seq in rank $i\n";
                1;
            }
        }
        else {      # Internal NN
            if ($DNA_IMM_table{$NN}) {
                $dH += $DNA_IMM_table{$NN}->[$dH_index];
                $dS += $DNA_IMM_table{$NN}->[$dS_index];
            }
            elsif ($DNA_IMM_table{$reverse_NN}) {
                $dH += $DNA_IMM_table{$reverse_NN}->[$dH_index];
                $dS += $DNA_IMM_table{$reverse_NN}->[$dS_index];
            }
            elsif ($DNA_NN_table{$NN}) {
                $dH += $DNA_NN_table{$NN}->[$dH_index];
                $dS += $DNA_NN_table{$NN}->[$dS_index];
            }
            elsif ($DNA_NN_table{$reverse_NN}) {
                $dH += $DNA_NN_table{$reverse_NN}->[$dH_index];
                $dS += $DNA_NN_table{$reverse_NN}->[$dS_index];
            }
            else {
                #die "No dH and dS value for $NN in $seq/$compl_seq in rank $i\n";
                1;
            }
        }
    }
    
    if ($ion_corr) {
        my $seq_len = length($seq);
        my $correction_factor = ion_correction($Na, $K, $Tris, $Mg, $dNTPs, $seq_len);
        $dS += $correction_factor;
    }
    my $x  =  4;          #   x = 4 if not self complementary; x = 1 if self complementary
    my $R = 1.9872;         #   Universal gas constant in Cal/degrees C*Mol
    $primer_conc = $primer_conc/1e9;   #   To convert nM into molar; do not multiply with 2 if the other strand is genomic DNA template, which can be negligible = 
    my $Tm  = sprintf "%.1f", (1000* $dH)/($dS + ($R * (log($primer_conc/$x))))-273.15;
    return $Tm; 
}

sub com {
    my $str = shift;
    $str = uc($str);
    $str =~ tr/ATGC/TACG/;
    return $str;
}

sub revcom {
    my $str = shift;
    $str = uc($str);
    $str =~ tr/ATGC/TACG/;
    return scalar(reverse($str));
}

sub draw {
    my ($str1, $str2, $pos2, $strand, $query, $fh) = @_;
    die "Not the same length for $str1/$str2\n" if (length($str1)!=length($str2));
    my @str1 = split //, $str1;
    my @str2 = split //, $str2;
    for my $i (0..$#str1) {
        if ($str1[$i] eq $str2[$i]) {
            $str2[$i] = ".";
        }
    }
    $str2 = join "", @str2;
    my $qs = 1;
    my $qe = length($str1);
    my $ts = $pos2;
    my $te = $strand==1 ? $ts+length($str1)-1 : $ts-length($str1)+1;
    my $name_len = max(length($query), length("Template"));
    my $num_len = length($pos2);
    printf {$fh} "%-${name_len}s %${num_len}d %s %-${num_len}d\n", $query, $qs, $str1, $qe;
    printf {$fh} "%-${name_len}s %${num_len}d %s %-${num_len}d\n", "Template", $ts, $str2, $te;
}

###############  Conduct end filling for BLAST alignments  ###############
my %query_seq;
{
    local $/ = ">";
    open my $fh, "<", "$dir/tmp.specificity.check/primer.query.fa";
    while (<$fh>) {
        chomp;
        next unless ($_);
        my ($id, @seqs) = split;
        my $seq = join '', @seqs;
        $query_seq{$id} = uc($seq);
    }
}
my %retrieve_region_data;
open $tmp_out_fh, ">", "$dir/tmp.specificity.check/retrieve.region.tmp";
open $in_fh, "<", "$dir/tmp.specificity.check/primer.query.fa.out.filterlength";
while (<$in_fh>) {
    chomp;
    my ($target, $ts, $te, $next_ts, $next_te, $size, $query, $qs, $qe, $next_query, $next_qs, $next_qe) = split;
    my $select_ts = $ts-$qs+1;
    my $select_te = $te+length($query_seq{$query})-$qe;     # $query: $id.$rank.Primer$i
    my $select_next_ts = $next_ts-length($query_seq{$next_query})+$next_qe;
    my $select_next_te = $next_te+$next_qs-1;
    next if ($select_ts<0 or $select_next_ts<0);    # This means failed to end filling
    print {$tmp_out_fh} "$target:$select_ts-$select_te\n$target:$select_next_ts-$select_next_te\n";
    push @{$retrieve_region_data{$query}}, ["$target:$select_ts-$select_te", "$target:$select_next_ts-$select_next_te", $next_query];
}
close $tmp_out_fh;
close $in_fh;
system "sort $dir/tmp.specificity.check/retrieve.region.tmp | uniq >$dir/tmp.specificity.check/retrieve.region.uniq.tmp";
system "xargs --arg-file=$dir/tmp.specificity.check/retrieve.region.uniq.tmp $samtools faidx $db >$dir/tmp.specificity.check/retrieve.region.tmp.fa";

my %target_seq;
{
    local $/ = ">";
    open my $fh, "<", "$dir/tmp.specificity.check/retrieve.region.tmp.fa";
    while (<$fh>) {
        chomp;
        next unless ($_);
        my ($id, @seqs) = split;
        my $seq = join '', @seqs;
        $target_seq{$id} = uc($seq);
    }
    close $fh;
}

###############  Calculate Tm and 3' end mismatch  ###############
if (!$detail) {
    open $out_fh, ">", "$dir/specificity.check.result.txt";
}
else {
    open $out_fh, ">", "$dir/specificity.check.result.html";
}

if (!$detail) {
    print {$out_fh} "#Site_ID\tPrimer_Rank\tPossible_Amplicon_Number\tPrimer_Seqs\n";
}
my %hit_num_for_primer;
my %hit_regions_for_primer;
open $tmp_out_fh, ">", "$dir/specificity.check.result.amplicon";
for my $i (0..$#run_array) {
    my $hit_num = 0;
    my ($id, $rank) = @{$run_array[$i]};
    open my $out, ">", "$dir/result.specificity.check/PrimerGroup.$id.$rank.txt";
    my @seqs = @{$primer_seq_for{$id}{$rank}};
    
    # calculate primers' own Tm (minimum)
    my $min_Tm_own = min( map{NN_Tm($_, com($_), $primer_conc, $Na, $K, $Tris, $Mg, $dNTPs, 1)}@seqs );
    print {$out} "Primer Group:\n";
    for my $j (0..$#seqs) {
        print {$out} $j+1, ":\t$seqs[$j]", "\n";
    }
    print {$out} "Minimum Melting Temperature (°C) for this group: $min_Tm_own\n\n";
    
    for my $j (0..$#seqs) { # BLAST query ID: $id.$rank.Primer$j
        my $query = "$id.$rank.Primer$j";
        if ($retrieve_region_data{$query}) {
            my @regions = @{$retrieve_region_data{$query}};
            for my $data_region (@regions) {
                my ($target_region, $target_next_region, $next_query) = @{$data_region};
                my $query_seq = $query_seq{$query};
                my $next_query_seq = $query_seq{$next_query};
                my $target_seq = $target_seq{$target_region};
                my $next_target_seq = revcom($target_seq{$target_next_region});
                my $Tm_1 = NN_Tm($query_seq, com($target_seq), $primer_conc, $Na, $K, $Tris, $Mg, $dNTPs, 1);
                my $Tm_2 = NN_Tm($next_query_seq, com($next_target_seq), $primer_conc, $Na, $K, $Tris, $Mg, $dNTPs, 1);
                next if ($Tm_1<$min_Tm_own-$min_Tm_diff or $Tm_2<$min_Tm_own-$min_Tm_diff);
                
                my $end1 = substr($query_seq, -1) eq substr($target_seq, -1) ? 'No' : 'Yes';
                my $end2 = substr($next_query_seq, -1) eq substr($next_target_seq, -1) ? 'No' : 'Yes';
                next if ($use_3end && ($end1 eq 'Yes' or $end2 eq 'Yes'));
                $hit_num++;
                
                # Generate Output
                print {$out} "############ Amplicon $hit_num ###########\n";
                my ($target_id, $target_start, $target_end) = $target_region=~/^(.*?)\:(\d+)-(\d+)$/;
                my ($next_target_start, $next_target_end) = $target_next_region=~/\:(\d+)-(\d+)$/;
                print {$out} "Template: $target_id\n";
                print {$out} "Template Region: $target_start-$next_target_end\n";
                push @{ $hit_regions_for_primer{$id}{$rank} }, [$target_id, $target_start, $next_target_end];
                print {$tmp_out_fh} "$id\t$rank\t$target_id\t$target_start\t$next_target_end\n";    # For design and check use only
                print {$out} "Primer Left: $query ($query_seq)\n";
                print {$out} "Primer Right: $next_query ($next_query_seq)\n";
                print {$out} "Product Size: ", $next_target_end-$target_start+1, " bp\n";
                print {$out} "Melting Temperature for Left Primer (°C): $Tm_1\n";
                print {$out} "Melting Temperature for Right Primer (°C): $Tm_2\n";
                print {$out} "Differ in the 3' End for Left Primer?: $end1\n";
                print {$out} "Differ in the 3' End for Right Primer?: $end2\n\n";
                
                draw($query_seq, $target_seq, $target_start, 1, 'Primer Left', $out);
                print {$out} "\n";
                
                draw($next_query_seq, $next_target_seq, $next_target_end, -1, 'Primer Right', $out);
                print {$out} "\n\n\n\n";
            }
        }
    }
    close $out;
    
    $hit_num_for_primer{$id}{$rank} = $hit_num;
    print {$out_fh} "$id\t$rank\t$hit_num\t@seqs\n" if (!$detail);
}
close $tmp_out_fh;
system "rm -rf $dir/tmp.specificity.check";

####### Print HTML  #########
if ($detail) {
        print {$out_fh} <<"END";
<div class="panel-group" id="primers-result" role="tablist">
END

    my $site_num = 0;
    for my $id (@ids) {
        $site_num++;
        my $primer_num = keys %{$hit_num_for_primer{$id}};
        print {$out_fh} <<"END";

<div class="panel panel-default">
    <div class="panel-heading" role="tab">
        <div class="row">
            <h4 class="panel-title col-md-1">
                <a class="collapsed" role="button" data-toggle="collapse" data-parent="#primers-result" href="#site-$site_num">
                    Site $site_num 
                    <span class="caret"></span>
                </a>
            </h4>
            <div class="col-md-3">
                <small>Site: $id</small>
            </div>
            <div class="col-md-2">
                <span class="badge">$primer_num</span> Primer(s)
            </div>
            <div class="col-md-1">
END
        my @hit_nums = values(%{$hit_num_for_primer{$id}});
        if ($hit_num_for_primer{$id} && 1~~@hit_nums ) {
            print {$out_fh} <<"END";
                <span class="glyphicon glyphicon-ok"></span>
END
        }
        print {$out_fh} <<"END";
            </div>
        </div>
    </div>
END
        if ($site_num==1) {
            print {$out_fh} <<"END";
    <div id="site-$site_num" class="panel-collapse collapse in" role="tabpanel">
        <div class="panel-body">
END
        }
        else {
            print {$out_fh} <<"END";
    <div id="site-$site_num" class="panel-collapse collapse" role="tabpanel">
        <div class="panel-body">
END
        }
        
        print {$out_fh} <<"END";
            <ul class="list-group">
END
        my @ranks = sort { $hit_num_for_primer{$id}{$a}<=>$hit_num_for_primer{$id}{$b} or $a<=>$b } keys %{$hit_num_for_primer{$id}};
        my $primer_output_rank = 1;
        for my $i (@ranks) {
            my $hit_num = $hit_num_for_primer{$id}{$i};
            if ($hit_num==1) {
                print {$out_fh} <<"END";
                    <li class="list-group-item list-group-item-success">
END
            }
            else {
                print {$out_fh} <<"END";
                    <li class="list-group-item">                    
END
            }        
            print {$out_fh} <<"END";
                        <h4 class="list-group-item-heading">Primer $primer_output_rank</h4>
                        <div class="list-group-item-text">
                            <div class="table-responsive">
                                <table class="table table-borderless">
                                    <thead>
                                        <tr>
                                            <th class="col-sm-2"></th>
                                            <th class="col-sm-4">Sequence (5' -&gt; 3')</th>
                                        </tr>
                                    </thead>
                                    <tbody>
END
            my @primer_seqs = @{$primer_seq_for{$id}{$i}};
            for my $j (0..$#primer_seqs) {
                my $output_seq_id = $j+1;
                print {$out_fh} <<"END";
                                        <tr>
                                            <th class="col-sm-2">Seq. $output_seq_id</th>
                                            <td class="col-sm-4"><span class="monospace-style">$primer_seqs[$j]</span></td>
                                        </tr>
END
            }
                
            print {$out_fh} <<"END";
                                        <tr>
                                            <th class="col-sm-2">Possible Amplicons Number</th>
                                            <td class="hit-num col-sm-4" data-hit="$hit_num">$hit_num 
                                                <a href="javascript:void(0)" data-toggle="modal" data-target="#specificity-check-modal" data-whatever="PrimerGroup.$id.$i.txt">
                                                    <span class="glyphicon glyphicon-hand-right"></span>
                                                </a>
                                            </td>
                                        </tr>
                                        <tr>
                                            <th class="col-sm-2">Possible Amplicons Regions</th>
                                            <td class="col-sm-4"><ul class="list-group"> 
END
            if ($hit_num>0) {
                my @hit_regions = @{ $hit_regions_for_primer{$id}{$i} };
                for my $j (0..$#hit_regions) {
                    my ($target_id, $target_start, $next_target_end) = @{$hit_regions[$j]};
                    my $size = $next_target_end-$target_start+1;
                    if ($hit_num==1) {
                        print {$out_fh} "<li class='list-group-item list-group-item-success'>$target_id:$target_start-$next_target_end, $size bp</li>";
                    }
                    else {
                        print {$out_fh} "<li class='list-group-item'>$target_id:$target_start-$next_target_end, $size bp</li>";
                    }
                    if ($j==4) {
                        print {$out_fh} "<li class='list-group-item'>...</li>";
                        last;
                    }
                }            
            }
            print {$out_fh} <<"END";
                                            </ul></td>
                                        </tr>
                                    </tbody>
                                </table>
                            </div>
                        </div>
                    </li>
END
            $primer_output_rank++;
        }
        print {$out_fh} <<"END";
            </ul>
        </div>
    </div>
</div>
END
    }
    
        print {$out_fh} <<"END";
</div>
END
}

close $out_fh;