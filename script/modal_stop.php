<?php

session_start();
$session_id = session_id();

exec("ps aux | grep apache | grep Primer | grep $session_id | awk '{print $2}'", $pids);

exec("kill -9 ".implode(' ',$pids));
