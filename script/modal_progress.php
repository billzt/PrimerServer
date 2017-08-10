<?php

session_start();
$session_id = session_id();
$date = date("Y-m-d");
$working_dir = "/tmp/Primer-$date-$session_id";

exec("grep '>' $working_dir/tmp.specificity.check/primer.query.*.fa | wc -l", $i);
exec("cut -f 1 $working_dir/tmp.specificity.check/*.out | uniq | sort | uniq | wc -l", $j);

if (count($i)==0 or count($j)==0) {
    echo json_encode(array(
        'total' => 0,
        'finished' => 0,
        'percent' => 0
    ));
    exit(0);
}

$all_primer_count = $i[0];
$finished_primer_count = $j[0];

if ($all_primer_count==0) {
    echo json_encode(array(
        'total' => 0,
        'finished' => 0,
        'percent' => 0
    ));
    exit(0);
}

$finished_percent = round($finished_primer_count/$all_primer_count*100);

echo json_encode(array(
    'total' => $all_primer_count,
    'finished' => $finished_primer_count,
    'percent' => $finished_percent
));
