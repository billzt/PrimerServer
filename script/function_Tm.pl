#!/usr/bin/env perl

use 5.010;
use strict;
use warnings;
use Getopt::Long;

my $usage = <<"END_USAGE";
usage: $0 --seq1=[SEQ:5'-3'] [Option]
Required:
--seq1     
Optional:
--seq2
--conc_primer
--conc_Na
--conc_K
--conc_Tris
--conc_Mg
--conc_dNTPs
--help      Print this help and exit
END_USAGE

my $help;
my $seq1;
my $seq2;
my $primer_conc = 100;    #nM  
my $Na          = 0;      #mM
my $K           = 50;     #mM
my $Tris        = 10;     #mM
my $Mg          = 1.5;    #mM  
my $dNTPs       = 0.2; #mM 

GetOptions(
    'help'          =>  \$help,
    'seq1=s'        =>  \$seq1,
    'seq2=s'        =>  \$seq2,
    'conc_primer=f' =>  \$primer_conc,
    'conc_Na=f'     =>  \$Na,
    'conc_K=f'      =>  \$K,
    'conc_Tris=f'   =>  \$Tris,
    'conc_Mg=f'     =>  \$Mg,
    'conc_dNTPs=f'  =>  \$dNTPs,
);

if ($help or !$seq1) {
    print "$usage";
    exit(0);
}


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


############ Judge whether seq2 has been provided  ############ 
if (!$seq2) {
    $seq2 = com($seq1);
}

############ Whether seq1 and seq2 is the same length  ############ 
if (length($seq1)!=length($seq2)) {
    die "Error: Not the same length of $seq1 and $seq2\n";
}

print "Tm: ", NN_Tm($seq1, $seq2, $primer_conc, $Na, $K, $Tris, $Mg, $dNTPs, 1), " C\n";

