<?php

session_start();
$session_id = session_id();
$date = date("Y-m-d");
$working_dir = "/tmp/Primer-$date-$session_id";

$file = $_GET['file'];

$file_str = file_get_contents("$working_dir/result.specificity.check/$file");

preg_match_all('/Product Size: (\d+) bp/m', $file_str, $length_matches);
$lengths = $length_matches[1];

echo json_encode(array(
    'file' => $file_str,
    'sizes' => array_values(array_unique($lengths)),
));