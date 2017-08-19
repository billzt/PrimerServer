<?php
    session_start();
    $session_id = session_id();
?>

<h4>Server Information</h4>
<ul>

<?php

$config = parse_ini_file("../config.ini");
$path_samtools = $config['samtools'];
$path_primer3 = $config['primer3'];
$path_blastn = $config['blastn'];
$show_info = $config['showInfo'];

if ($show_info) {
    // memory
    exec("less /proc/meminfo | grep MemTotal | awk '{print $2}'", $mem_total);
    $mem_total_result = number_format($mem_total[0]);
    exec("less /proc/meminfo | grep MemFree | awk '{print $2}'", $mem_free);
    $mem_free_result = number_format($mem_free[0]);

    // cpu
    exec("less /proc/cpuinfo | grep 'model name' | uniq | cut -f 2", $cpu_info);

?>
    <li>Server: <?php echo $_SERVER['SERVER_SOFTWARE'] ?></li>
    <li>PHP Version: <?php echo PHP_VERSION ?></li>
    <li>CPU info<?php echo $cpu_info[0] ?></li>
    <li>Memory Total: <?php echo $mem_total_result ?> kB</li>
    <li>Memory Free: <?php echo $mem_free_result ?> kB</li>
    <li>Current Session: <?php echo $session_id ?></li>
<?php
}
    
    // Software
    exec("$path_samtools --version | head -n 1 | awk '{print $2}'", $version_samtools);
    exec("$path_blastn -version | head -n 1 | awk '{print $2}'", $version_blastn);
    exec("$path_primer3 -version 2>&1 | grep 'libprimer3 release' | awk '{print $6}'", $version_primer3);
    
    // current time
    $time = date("Y-m-d H:i:s");
    $time_diff = date("P");
?>
    <li>Primer3: <?php echo str_replace(')', '', $version_primer3[0]) ?></li>
    <li>Samtools: <?php echo $version_samtools[0] ?></li>
    <li>BLASTn: <?php echo $version_blastn[0] ?></li>
    <li>Current Time: <?php echo $time, " GMT ", $time_diff ?></li>
</ul>

