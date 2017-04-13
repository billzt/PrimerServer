<?php

session_start();
$session_id = session_id();
$date = date("Y-m-d");
$working_dir = "/tmp/Primer-$date-$session_id";

$file = $_GET['file'];

$file_str = file_get_contents("$working_dir/result.MFEPrimer/$file");

preg_match('/on the query primers(.*)Details for the primers binding to the DNA template/s', $file_str, $list_matches);
$list = $list_matches[1];

preg_match_all('/^\d+:\s+\S+\s+(\d+)\s+.*$/m', $list, $length_matches);
$lengths = $length_matches[1];

echo json_encode(array(
    'file' => $file_str,
    'sizes' => array_values(array_unique($lengths)),
));