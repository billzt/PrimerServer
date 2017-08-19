<?php

session_start();
$session_id = session_id();
$date = date("Y-m-d");
$working_dir = "/tmp/Primer-$date-$session_id";

$config = parse_ini_file("../config.ini");
if($config['removeTmp']) {
    exec("rm -rf $working_dir");
}
