<?php

session_start();
$session_id = session_id();
$date = date("Y-m-d");
$working_dir = "/tmp/Primer-$date-$session_id";

$all_primer_count = count(glob("$working_dir/tmp.MFEPrimer/*.txt"));
$finished_primer_count = count(glob("$working_dir/tmp.MFEPrimer/*.txt.out"));

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
