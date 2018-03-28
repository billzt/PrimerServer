<?php

session_start();
$session_id = session_id();
$date = date("Y-m-d");
$working_dir = "/tmp/Primer-$date-$session_id";

exec("ps aux | grep Primer | grep $session_id | awk '{print $2}'", $pids);

exec("kill -9 ".implode(' ',$pids));

exec("rm -rf $working_dir/*.tmp $working_dir/tmp.*");

