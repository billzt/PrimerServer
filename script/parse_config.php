<?php

$config = parse_ini_file("../config.ini");

echo json_encode(array(
    'limitDatabase' => $config['limitDatabase'],
));
