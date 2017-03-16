<?php

session_start();
$session_id = session_id();
$date = date("Y-m-d");
$working_dir = "/tmp/Primer-$date-$session_id";

$file = $_GET['file'];
echo file_get_contents("$working_dir/result.MFEPrimer/$file");