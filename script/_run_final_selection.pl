#!/usr/bin/env perl

use 5.010;
use strict;
use warnings;
use Fatal qw/open close chdir/;
use Getopt::Long;
use List::Util qw/sum/;
use File::Basename qw/basename/;

my $usage = <<"END_USAGE";
usage: $0 --primer3result=<primer3 result> --specificity=<specificity result> [Option]
--primer3result     
--specificity 
--db 
--region_type SEQUENCE_TARGET; SEQUENCE_INCLUDED_REGION; FORCE_END
--outputdir
--retain
--amplicon
--help      Print this help and exit
END_USAGE

my $help;
my $primer3result;
my $specificity;
my $db;
my $detail;
my $retain = 10;
my $amplicon;
my $dir = ".";
my $region_type = "SEQUENCE_TARGET";

GetOptions(
    'help'          =>  \$help,
    'primer3result=s'       =>  \$primer3result,
    'specificity=s'       =>  \$specificity,
    'outputdir=s'   =>  \$dir,
    'db=s'          =>  \$db,
    'detail'      =>  \$detail,
    'retain=i'      =>  \$retain,
    'region_type=s' =>  \$region_type,
    'amplicon=s'    =>  \$amplicon,
);

if ($help or !$primer3result or !$specificity) {
    print "$usage";
    exit(0);
}

my @dbs = split /,/, $db;
my $primary_db = basename $dbs[0];   # This is the primary database used to judge primer specificity

my %hit_num_for_primer;
my %success_site;       # Judge whether this site has unique primers in at least one of the databases
open my $in_fh, "<", $specificity;
while (<$in_fh>) {
    chomp;
    next if (/^#/);
    my ($id, $rank, $each_db, $num) = split;
    $hit_num_for_primer{$id}{$rank}{$each_db} = $num;
    if ($num==1 && $each_db eq $primary_db) {
        $success_site{$id} = 1;
    }
}
close $in_fh;

my %hit_regions_for_primer;
open $in_fh, "<", $amplicon;
while (<$in_fh>) {
    chomp;
    next if (/^#/);
    my ($id, $rank, $each_db, $target_id, $target_start, $next_target_end) = split;
    push @{ $hit_regions_for_primer{$id}{$rank}{$each_db} }, [$target_id, $target_start, $next_target_end];
}
close $in_fh;

my %data_for_primer;
{
    local $/ = "\n=\n";
    open my $in_fh, "<", $primer3result;
    my $out_fh;
    if (!$detail) {
        open $out_fh, ">", "$dir/primer.final.result.txt";
    }
    else {
        open $out_fh, ">", "$dir/primer.final.result.html";
    }
    
    if ($detail) {
        print {$out_fh} <<"END";
<div class="panel-group" id="primers-result" role="tablist">
END
    }
    else {
        print {$out_fh} "### Site_ID\tPrimer_Rank\tPrimer_Seq_Left\tPrimer_Seq_Right\tTarget_Amplicon_Size\tPrimer_Pair_Penalty_Score\tDatabase\tPossible_Amplicon_Number\tPrimer_Rank_in_Primer3_output\n";
    }
    
    my $site_num = 0;
    while (<$in_fh>) {
        chomp;
        $site_num++;
        my ($id) = /SEQUENCE_ID=(\S+)/; 
        
        # SEQUENCE_ID=$chr-$target_start-$target_length 
        # SEQUENCE_TARGET=$relative_target_start,$target_length
        # OR SEQUENCE_INCLUDED_REGION=$relative_target_start,$target_length
        # OR SEQUENCE_FORCE_LEFT_END=$relative_target_start SEQUENCE_FORCE_RIGHT_END=$relative_target_start
        # $relative_target_start = $target_start-$retrieve_start+1 => $retrieve_start=$target_start-$relative_target_start+1
        my ($chr, $target_start, $target_length, $tag) = $id=~/^(.*)-(\d+)-(\d+)-?(\w+)?$/;
        my $relative_target_start;
        if ($region_type eq 'FORCE_END') {
            if (/SEQUENCE_FORCE_LEFT_END/) {
                ($relative_target_start) = /SEQUENCE_FORCE_LEFT_END=(\d+)/;
            }
            else {
                ($relative_target_start) = /SEQUENCE_FORCE_RIGHT_END=(\d+)/;
            }
        }
        else {
            ($relative_target_start) = /$region_type=(\d+),/;
        }
        my $retrieve_start = $target_start-$relative_target_start;
        
        my ($primer_num) = /PRIMER_PAIR_NUM_RETURNED=(\S+)/; $primer_num=$primer_num>$retain?$retain:$primer_num;

        if ($detail) {
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
                data-length="$target_length">Template $chr; Target Pos: $target_start; Target Length: $target_length
END
            if ($tag) {
                print {$out_fh} " [$tag] ";
            }
            print {$out_fh} <<"END";
                </small>
            </div>
            <div class="col-md-2">
                <span class="badge">$primer_num</span> Primer(s)
            </div>
            <div class="col-md-1">
END
            if ($hit_num_for_primer{$id} && $success_site{$id} ) {  # This site has unique primers in the primary database
                print {$out_fh} <<"END";
                <span class="glyphicon glyphicon-ok"></span>
END
            }
            
            print {$out_fh} <<"END";
            </div>
        </div>
    </div>
END
            if ($site_num==1) { # This is the first site, expand the panel
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
            if (!$detail) {
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
                </div>
            </div>
END
            }
        }
        else {
            if ($detail) {
                print {$out_fh} <<"END";
            <div class="PrimerFigure"></div>
            <ul class="list-group">
END
            }
            # sort primers: first by hit numbers (on primary database), then by primer3 score
            my @ranks = sort { $hit_num_for_primer{$id}{$a}{$primary_db}<=>$hit_num_for_primer{$id}{$b}{$primary_db} or $a<=>$b } keys %{$hit_num_for_primer{$id}};
            my $primer_output_rank = 1;
            for my $i (@ranks) {
                my ($seq_F) = /PRIMER_LEFT_ $i _SEQUENCE=(\S+)/x;
                my ($seq_R) = /PRIMER_RIGHT_ $i _SEQUENCE=(\S+)/x;
                
                my ($pos_F, $len_F) = /PRIMER_LEFT_ $i =(\d+),(\d+)/x;
                my ($pos_R, $len_R) = /PRIMER_RIGHT_ $i =(\d+),(\d+)/x;
                my $start_F = $pos_F+$retrieve_start;
                my $end_F = $start_F+$len_F-1;
                my $end_R = $pos_R+$retrieve_start;
                my $start_R = $end_R-$len_R+1;
                
                
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
                
                my @databases = map {basename($_)} @dbs;
                if (!$detail) {
                    for my $database (@databases) {
                        my $hit_num = $hit_num_for_primer{$id}{$i}{$database};
                        print {$out_fh} "$id\t$primer_output_rank\t$seq_F\t$seq_R\t$size\t$penalty_pair\t$database\t$hit_num\t$i\n";
                    }
                }
                else {
                    if ($hit_num_for_primer{$id}{$i}{$primary_db}==1) { # This primer has unique hit in the primary database
                        print {$out_fh} <<"END";
                    <li class="list-group-item list-group-item-primer list-group-item-success">
END
                    }
                    else {
                        print {$out_fh} <<"END";
                    <li class="list-group-item list-group-item-primer">                    
END
                    }
                    print {$out_fh} <<"END";
                        <h4 class="list-group-item-heading" id="Site$site_num-Primer$primer_output_rank">Primer $primer_output_rank</h4>
                        <div class="list-group-item-text">
                            <div class="table-responsive">
                                <table class="table table-borderless">
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
                                        <td colspan="9">$size bp</td>
                                    </tr>
                                    <tr>
                                        <th>Penalty</th>
                                        <td colspan="9" class="penalty">$penalty_pair</td>
                                    </tr>
                                 </table>
                                 <table class="table table-bordered">
                                    <tr>
                                        <th class="col-sm-2" rowspan=3 >Possible Amplicons</th>
END
                    
                    for my $database (@databases) {
                        if ($database eq $primary_db) {
                            print {$out_fh} <<"END";
                                        <th>Database: $database <span class="glyphicon glyphicon-star"></span></th>
END
                        }
                        else {
                            print {$out_fh} <<"END";
                                        <th>Database: $database</th>
END
                        }
                    }
                    print {$out_fh} <<"END";
                                    </tr>
                                    <tr>
END
                    for my $database (@databases) {
                        my $hit_num = $hit_num_for_primer{$id}{$i}{$database};
                        print {$out_fh} <<"END";
                                        <td class="hit-num" data-hit="$hit_num">Amplicon Number: $hit_num 
                                            <a href="javascript:void(0)" data-toggle="modal" data-target="#specificity-check-modal" 
                                            data-whatever="PrimerGroup.$database.$id.$i.txt" data-targetsize="$size">
                                                <span class="glyphicon glyphicon-hand-right"></span>
                                            </a>
                                        </td>
END
                    }
                    print {$out_fh} <<"END";
                                    </tr>
                                    <tr>
END
                    for my $database (@databases) {
                        print {$out_fh} <<"END";
                                            <td><ul class="list-group"> 
END
                        my $hit_num = $hit_num_for_primer{$id}{$i}{$database};
                        if ($hit_num>0) {
                            my @hit_regions = @{ $hit_regions_for_primer{$id}{$i}{$database} };
                            for my $j (0..$#hit_regions) {
                                my ($target_id, $target_start, $next_target_end) = @{$hit_regions[$j]};
                                my $size = $next_target_end-$target_start+1;
                                if ($hit_num_for_primer{$id}{$i}{$primary_db}==1) {
                                    print {$out_fh} <<"END";
                                                <li class='list-group-item list-group-item-success'>$target_id:$target_start-$next_target_end, $size bp</li>
END
                                }
                                else {
                                    print {$out_fh} <<"END";
                                                <li class='list-group-item'>$target_id:$target_start-$next_target_end, $size bp</li>
END
                                }
                                if ($j==2) {
                                    if ($hit_num_for_primer{$id}{$i}{$primary_db}==1) {
                                        print {$out_fh} "<li class='list-group-item list-group-item-success'>...</li>";
                                    }
                                    else {
                                        print {$out_fh} "<li class='list-group-item'>...</li>";
                                    }
                                    last;
                                }
                            }
                        }
            print {$out_fh} <<"END";
                                            </ul></td>
END
                    }
            print {$out_fh} <<"END";
                                     </tr>
                                </table>
                            </div>
                        </div>
                    </li>
END
                }
                last if ($primer_output_rank==$retain);
                $primer_output_rank++;
            }
            if ($detail) {
                print {$out_fh} <<"END";
            </ul>
END
            }
        
        }
        
        if (!$detail) {
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
    
    if ($detail) {
            print {$out_fh} <<"END";
</div>
END
    }
    close $out_fh;
    close $in_fh;
}

