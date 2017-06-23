<?php

session_start();
$session_id = session_id();
$date = date("Y-m-d");
$working_dir = "/tmp/Primer-$date-$session_id";
$config = parse_ini_file("../config.ini");
$database_dir = $config['database'];

function download_file($file_url,$new_basename=''){
    if(!isset($file_url)||trim($file_url)==''){ // trim: remove blanks surround string
        return '500';
    }
    if(!file_exists($file_url)){ // whether file exists ?
        return '404';
    }
    $file_basename = basename($file_url);
    $file_type = explode('.',$file_basename); // explode: split
    $file_type = end($file_type); // end: last items of array
    $file_fullname = trim($new_basename=='') ? $file_basename : urlencode($new_basename).'.'.$file_type;

    // file mark
    header('Content-type: application/octet-stream');
    header('Accept-Ranges: bytes');
    header('Accept-Length: '.filesize($file_url));
    header('Content-Disposition: attachment; filename='.$file_fullname);
    
    // file content
    @readfile($file_url); // read file $file_url and print it. "@" indicates no warnings
}

$id = $_GET['file'];
$file = "$database_dir/$id.fai";

exec("cut -f 1,2 $file >$working_dir/ID.txt");
download_file("$working_dir/ID.txt");

