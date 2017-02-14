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
--size_start
--size_stop
--pypy
--outputdir
--detail
--retain
--help      Print this help and exit
END_USAGE

my $help;
my $input;
my $db;
my $pypy = "pypy";
my $dir = ".";
my $size_start = 50;
my $size_stop = 5000;
my $detail = 0;
my $retain = 10;

GetOptions(
    'help'          =>  \$help,
    'input=s'       =>  \$input,
    'db=s'          =>  \$db,
    'pypy=s'        =>  \$pypy,
    'outputdir=s'   =>  \$dir,
    'size_start=i'  =>  \$size_start,
    'size_stop=i'   =>  \$size_stop,
    'detail=i'      =>  \$detail,
    'retain=i'      =>  \$retain,
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
# if (!-e($input)) {
    # die "Can not find file $input\n";
# }
# if (!-e($db)) {
    # die "Can not find file $db\n";
# }

####### Generate MFEPrimer input and Run one by one #########
open my $in_fh, "<", $input;
my $out_fh;
if ($detail==0) {
    open $out_fh, ">", "$dir/specificity.check.result.txt";
}
else {
    open $out_fh, ">", "$dir/specificity.check.result.html";
}
mkdir "$dir/tmp.MFEPrimer" unless (-e "$dir/tmp.MFEPrimer");
my %hit_num_for_primer;
my %primer_seq_for;
my @ids;    # Only used to keep order of site id;
while (<$in_fh>) {
    chomp;
    my ($id, $rank, @seqs) = split;
    open my $tmp_out_fh, ">", "$dir/tmp.MFEPrimer/$id.$rank.txt";
    for my $i (0..$#seqs) {
        print {$tmp_out_fh} ">$id.$rank.Primer$i\n$seqs[$i]\n";
    }
    close $tmp_out_fh;
    system "$pypy ../MFEprimer/MFEprimer.py -i $dir/tmp.MFEPrimer/$id.$rank.txt -d $db --size_start=$size_start --size_stop=$size_stop >$dir/tmp.MFEPrimer/$id.$rank.txt.out";
    
    my $hit_num_line = `grep 'potential PCR amplicon' $dir/tmp.MFEPrimer/$id.$rank.txt.out`;
    my ($hit_num) = $hit_num_line=~/Distribution of (\d+) potential PCR amplicon/;
    print {$out_fh} "$id\t$rank\t$hit_num\t@seqs\n" if ($detail==0);
    $hit_num_for_primer{$id}{$rank} = $hit_num;
    $primer_seq_for{$id}{$rank} = [@seqs];
    push @ids, $id if(!($id~~@ids));
    system "rm -f $dir/tmp.MFEPrimer/$id.$rank.txt";
}
close $in_fh;

if ($detail==1) {
        print {$out_fh} <<"END";
<h2 class="page-header">Result</h2>
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
        if ($hit_num_for_primer{$id} && values %{$hit_num_for_primer{$id}}~~1 ) {
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
                                            <th></th>
                                            <th>Sequence (5' -&gt; 3')</th>
                                        </tr>
                                    </thead>
                                    <tbody>
END
            my @primer_seqs = @{$primer_seq_for{$id}{$i}};
            for my $j (0..$#primer_seqs) {
                my $output_seq_id = $j+1;
                print {$out_fh} <<"END";
                                        <tr>
                                            <th>Seq. $output_seq_id</th>
                                            <td><span class="monospace-style">$primer_seqs[$j]</span></td>
                                        </tr>
END
            }
                
            print {$out_fh} <<"END";
                                        <tr>
                                            <th>Hit Number</th>
                                            <td>$hit_num 
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
            last if ($primer_output_rank==$retain);
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

