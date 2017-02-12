<?php

session_start();
$session_id = session_id();
$working_dir = "../tmp/$session_id";

$file = $_GET['file'];
echo file_get_contents("$working_dir/tmp.MFEPrimer/$file");