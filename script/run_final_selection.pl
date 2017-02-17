#!/usr/bin/perl

use 5.010;
use strict;
use warnings;
use Fatal qw/open close chdir/;
use Getopt::Long;

my $usage = <<"END_USAGE";
usage: $0 --primer3result=<primer3 result> --specificity=<specificity result> [Option]
Required:
--primer3result     
--specificity 
Optional:
--outputdir
--detail
--retain
--help      Print this help and exit
END_USAGE

my $help;
my $primer3result;
my $specificity;
my $detail = 0;
my $retain = 10;
my $dir = ".";

GetOptions(
    'help'          =>  \$help,
    'primer3result=s'       =>  \$primer3result,
    'specificity=s'       =>  \$specificity,
    'outputdir=s'   =>  \$dir,
    'detail=i'      =>  \$detail,
    'retain=i'      =>  \$retain,
);

if ($help or !$primer3result or !$specificity) {
    print "$usage";
    exit(0);
}

my %hit_num_for_primer;
open my $in_fh, "<", $specificity;
while (<$in_fh>) {
    chomp;
    next if (/^#/);
    my ($id, $rank, $num) = split;
    $hit_num_for_primer{$id}{$rank} = $num;
}
close $in_fh;

my %data_for_primer;
{
    local $/ = "\n=\n";
    open my $in_fh, "<", $primer3result;
    my $out_fh;
    if ($detail==0) {
        open $out_fh, ">", "$dir/primer.final.result.txt";
    }
    else {
        open $out_fh, ">", "$dir/primer.final.result.html";
    }
    
    if ($detail==1) {
        print {$out_fh} <<"END";
<div class="panel-group" id="primers-result" role="tablist">
END
    }
    
    my $site_num = 0;
    while (<$in_fh>) {
        chomp;
        $site_num++;
        my ($id) = /SEQUENCE_ID=(\S+)/; 
        
        # SEQUENCE_ID=$chr-$target_start-$target_length 
        # SEQUENCE_TARGET=$relative_target_start,$target_length
        # $relative_target_start = $target_start-$retrieve_start+1 => $retrieve_start=$target_start-$relative_target_start+1
        my ($chr, $target_start, $target_length) = $id=~/^(.*)-(\d+)-(\d+)$/;
        my ($relative_target_start) = /SEQUENCE_TARGET=(\d+),/;
        my $retrieve_start = $target_start-$relative_target_start+1;
        
        my ($primer_num) = /PRIMER_PAIR_NUM_RETURNED=(\S+)/; $primer_num=$primer_num>$retain?$retain:$primer_num;

        if ($detail==1) {
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
                <small class="site-detail" data-seq="$chr" data-pos="$target_start" 
                data-length="$target_length">Template $chr; Target Pos: $target_start; Target Length: $target_length</small>
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
        }
        if ($primer_num==0) {
            my ($PRIMER_LEFT_EXPLAIN) = /PRIMER_LEFT_EXPLAIN=(.*)/;
            my ($PRIMER_RIGHT_EXPLAIN) = /PRIMER_RIGHT_EXPLAIN=(.*)/;
            my ($PRIMER_PAIR_EXPLAIN) = /PRIMER_PAIR_EXPLAIN=(.*)/;
            if ($detail==0) {
                print {$out_fh} "$id\tNo_Primer\t$PRIMER_LEFT_EXPLAIN\t$PRIMER_RIGHT_EXPLAIN\t$PRIMER_PAIR_EXPLAIN\n";
            }
            else {
                print {$out_fh} <<"END";
            <div class="row">
                <div class="alert alert-danger" role="alert">
                    <h4>WARNING: No appropriate primers. Explain:</h4>
                    <p>Left primer: $PRIMER_LEFT_EXPLAIN</p>
                    <p>Right primer: $PRIMER_RIGHT_EXPLAIN</p>
                    <p>Pair: $PRIMER_PAIR_EXPLAIN</p>
                    <b>If you did not see any explainations here, then it is probably that you give wrong sequence IDs</b>
                </div>
            </div>
END
            }
        }
        else {
            if ($detail==1) {
                print {$out_fh} <<"END";
            <div class="PrimerFigure"></div>
            <ul class="list-group">
END
            }
            my @ranks = sort { $hit_num_for_primer{$id}{$a}<=>$hit_num_for_primer{$id}{$b} or $a<=>$b } keys %{$hit_num_for_primer{$id}};
            my $primer_output_rank = 1;
            for my $i (@ranks) {
                my ($seq_F) = /PRIMER_LEFT_ $i _SEQUENCE=(\S+)/x;
                my ($seq_R) = /PRIMER_RIGHT_ $i _SEQUENCE=(\S+)/x;
                
                my ($pos_F, $len_F) = /PRIMER_LEFT_ $i =(\d+),(\d+)/x;
                my ($pos_R, $len_R) = /PRIMER_RIGHT_ $i =(\d+),(\d+)/x;
                my $start_F = $pos_F+$retrieve_start-1;
                my $end_F = $start_F+$len_F-1;
                my $start_R = $pos_R+$retrieve_start-1;
                my $end_R = $start_R+$len_R-1;
                
                my ($Tm_F) = /PRIMER_LEFT_ $i _TM=(\S+)/x; $Tm_F=sprintf("%.1f", $Tm_F);
                my ($Tm_R) = /PRIMER_RIGHT_ $i _TM=(\S+)/x; $Tm_R=sprintf("%.1f", $Tm_R);
                
                my ($GC_F) = /PRIMER_LEFT_ $i _GC_PERCENT=(\S+)/x; $GC_F=sprintf("%.1f", $GC_F);
                my ($GC_R) = /PRIMER_RIGHT_ $i _GC_PERCENT=(\S+)/x; $GC_R=sprintf("%.1f", $GC_R);
                
                my ($self_any_F) = /PRIMER_LEFT_ $i _SELF_ANY_TH=(\S+)/x; $self_any_F=sprintf("%.1f", $self_any_F);
                my ($self_any_R) = /PRIMER_RIGHT_ $i _SELF_ANY_TH=(\S+)/x; $self_any_R=sprintf("%.1f", $self_any_R);
                
                my ($self_end_F) = /PRIMER_LEFT_ $i _SELF_END_TH=(\S+)/x; $self_end_F=sprintf("%.1f", $self_end_F);
                my ($self_end_R) = /PRIMER_RIGHT_ $i _SELF_END_TH=(\S+)/x; $self_end_R=sprintf("%.1f", $self_end_R);
                
                my ($hairpin_F) = /PRIMER_LEFT_ $i _HAIRPIN_TH=(\S+)/x; $hairpin_F=sprintf("%.1f", $hairpin_F);
                my ($hairpin_R) = /PRIMER_RIGHT_ $i _HAIRPIN_TH=(\S+)/x; $hairpin_R=sprintf("%.1f", $hairpin_R);
                
                my ($end_stable_F) = /PRIMER_LEFT_ $i _END_STABILITY=(\S+)/x; $end_stable_F=sprintf("%.1f", $end_stable_F);
                my ($end_stable_R) = /PRIMER_RIGHT_ $i _END_STABILITY=(\S+)/x; $end_stable_R=sprintf("%.1f", $end_stable_R);
                
                my ($pair_any) = /PRIMER_PAIR_ $i _COMPL_ANY_TH=(\S+)/x; $pair_any=sprintf("%.1f", $pair_any);
                
                my ($pair_end) = /PRIMER_PAIR_ $i _COMPL_END_TH=(\S+)/x; $pair_end=sprintf("%.1f", $pair_end);
                
                my ($size) = /PRIMER_PAIR_ $i _PRODUCT_SIZE=(\S+)/x;
                
                my ($penalty_pair) = /PRIMER_PAIR_ $i _PENALTY=(\S+)/x; $penalty_pair=sprintf("%.1f", $penalty_pair);
                
                my $hit_num = $hit_num_for_primer{$id}{$i};
                if ($detail==0) {
                    print {$out_fh} "$id\t$primer_output_rank\t$seq_F\t$seq_R\t$size\t$penalty_pair\t$hit_num\n";
                }
                else {
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
                        <h4 class="list-group-item-heading" id="Site$site_num-Primer$primer_output_rank">Primer $primer_output_rank</h4>
                        <div class="list-group-item-text">
                            <div class="table-responsive">
                                <table class="table table-borderless">
                                    <thead>
                                        <tr>
                                            <th></th>
                                            <th>Sequence (5' -&gt; 3')</th>
                                            <th>Length</th>
                                            <th>Position</th>
                                            <th>Tm(&deg;C)</th>
                                            <th>GC(%)</th>
                                            <th>Self Compl.</th>
                                            <th>3' Self Compl.</th>
                                            <th>Hairpin</th>
                                            <th>3' End Stability</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        <tr>
                                            <th>Left Primer</th>
                                            <td><span class="monospace-style">$seq_F</span></td>
                                            <td>$len_F</td>
                                            <td class="primer-left-region">$start_F-$end_F</td>
                                            <td>$Tm_F</td>
                                            <td>$GC_F</td>
                                            <td>$self_any_F</td>
                                            <td>$self_end_F</td>
                                            <td>$hairpin_F</td>
                                            <td>$end_stable_F</td>
                                        </tr>
                                        <tr>
                                            <th>Right Primer</th>
                                            <td><span class="monospace-style">$seq_R</span></td>
                                            <td>$len_R</td>
                                            <td class="primer-right-region">$start_R-$end_R</td>
                                            <td>$Tm_R</td>
                                            <td>$GC_R</td>
                                            <td>$self_any_R</td>
                                            <td>$self_end_R</td>
                                            <td>$hairpin_R</td>
                                            <td>$end_stable_R</td>
                                        </tr>
                                        <tr>
                                            <th>Product Size</th>
                                            <td colspan="9">$size</td>
                                        </tr>
                                        <tr>
                                            <th>Penalty</th>
                                            <td colspan="9">$penalty_pair</td>
                                        </tr>
                                        <tr>
                                            <th>Possible Amplicons Number</th>
                                            <td colspan="9" class="hit-num" data-hit="$hit_num">$hit_num 
                                                <a href="javascript:void(0)" data-toggle="modal" data-target="#specificity-check-modal" data-whatever="$id.$i.txt.out">
                                                    <span class="glyphicon glyphicon-hand-right"></span>
                                                </a>
                                            </td>
                                        </tr>
                                    </tbody>
                                </table>
                            </div>
                        </div>
                    </li>
END
                }
                last if ($primer_output_rank==$retain);
                $primer_output_rank++;
            }
            if ($detail==1) {
                print {$out_fh} <<"END";
            </ul>
END
            }
        
        }
        
        if ($detail==0) {
            print {$out_fh} "###\n";
        }
        else {
            print {$out_fh} <<"END";
        </div>
    </div>
</div>
END
        }
    }
    
    if ($detail==1) {
            print {$out_fh} <<"END";
</div>
END
    }
    close $out_fh;
    close $in_fh;
}

