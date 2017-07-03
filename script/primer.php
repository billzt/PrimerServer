<?php

// Generate random session directory
session_start();
$session_id = session_id();
$date = date("Y-m-d");
$working_dir = "/tmp/Primer-$date-$session_id";
session_write_close();  // This is very important as this script might execute for a long time
if (!file_exists($working_dir)) {
    mkdir($working_dir);
}

// App type
$type = $_POST['app-type'];
switch($type) {
    case 'design': echo '<h2 class="page-header">Primers Design &amp; Check Result</h2>';break;
    case 'check': echo '<h2 class="page-header">Primers Check Result</h2>';break;
    default: break;
}

// Program Path and parameter
$config = parse_ini_file("../config.ini");
$path_samtools = $config['samtools'];
$path_primer3 = $config['primer3'];
$path_blastn = $config['blastn'];
$limit_site = $config['limitSite'];
$limit_primer = $config['limitPrimer'];
$cpu = $config['useCPU'];
$database_dir = $config['database'];

// design & check Primers
if ($type=='design') {
    
    // check parameter
    require 'parameter_checker.php';
    
    // generate Primer3 setting file
    $p3_settings_string =  <<<END
Primer3 File - http://primer3.sourceforge.net
P3_FILE_TYPE=settings

PRIMER_EXPLAIN_FLAG=1
PRIMER_NUM_RETURN=$_POST[PRIMER_NUM_RETURN]
PRIMER_MIN_SIZE=$_POST[PRIMER_MIN_SIZE]
PRIMER_OPT_SIZE=$_POST[PRIMER_OPT_SIZE]
PRIMER_MAX_SIZE=$_POST[PRIMER_MAX_SIZE]
PRIMER_MIN_TM=$_POST[PRIMER_MIN_TM]
PRIMER_OPT_TM=$_POST[PRIMER_OPT_TM]
PRIMER_MAX_TM=$_POST[PRIMER_MAX_TM]
PRIMER_PAIR_MAX_DIFF_TM=$_POST[PRIMER_PAIR_MAX_DIFF_TM]
PRIMER_MIN_GC=$_POST[PRIMER_MIN_GC]
PRIMER_OPT_GC_PERCENT=$_POST[PRIMER_OPT_GC_PERCENT]
PRIMER_MAX_GC=$_POST[PRIMER_MAX_GC]
PRIMER_MAX_END_STABILITY=$_POST[PRIMER_MAX_END_STABILITY]
PRIMER_LOWERCASE_MASKING=$_POST[PRIMER_LOWERCASE_MASKING]
PRIMER_MIN_LEFT_THREE_PRIME_DISTANCE=$_POST[PRIMER_MIN_LEFT_THREE_PRIME_DISTANCE]
PRIMER_MIN_RIGHT_THREE_PRIME_DISTANCE=$_POST[PRIMER_MIN_RIGHT_THREE_PRIME_DISTANCE]
PRIMER_MAX_SELF_ANY_TH=$_POST[PRIMER_MAX_SELF_ANY_TH]
PRIMER_PAIR_MAX_COMPL_ANY_TH=$_POST[PRIMER_PAIR_MAX_COMPL_ANY_TH]
PRIMER_MAX_SELF_END_TH=$_POST[PRIMER_MAX_SELF_END_TH]
PRIMER_PAIR_MAX_COMPL_END_TH=$_POST[PRIMER_PAIR_MAX_COMPL_END_TH]
PRIMER_MAX_HAIRPIN_TH=$_POST[PRIMER_MAX_HAIRPIN_TH]
=
END;
    file_put_contents("$working_dir/p3_settings_file", $p3_settings_string);
    
    // ####### collect user's input data #######
    // template species
    $template_tax = $_POST['select-template'];
    if ($template_tax=='custom') {
        $database_dir = "../temp";
        file_put_contents("$database_dir/custom", $_POST['custom-template-sequences']);
        // check whether file custom is a DNA FASTA format file
        exec("$path_samtools faidx $database_dir/custom");
        if (!file_exists("$database_dir/custom.fai")) {  // index FASTA is not OK
?>
<div class="alert alert-danger" role="alert">
    Error: Building index of your input FASTA failed! Either your input sequences are not in FASTA
    format or there are some error in this web setting.
</div>

<?php
            exit(0);
        }
    }
    
    //  input region and checking database
    $input_regions = stripslashes(strip_tags(trim($_POST['template-regions'])));
    $input_regions_array = array_filter(explode("\n", $input_regions), create_function('$v','return !empty($v);'));
    $input_region_num = count($input_regions_array);
    $input_regions_array = array_unique($input_regions_array);
    $input_region_num_unique = count($input_regions_array);
?>
<div class="alert alert-info alert-dismissible" role="alert">
    <button type="button" class="close" data-dismiss="alert" aria-label="Close"><span aria-hidden="true">&times;</span></button>
    <b><?php echo $input_region_num ?></b> site(s) detected; <b><?php echo $input_region_num_unique ?></b> site(s) used
</div>
<?php
    if ($input_region_num_unique>$limit_site) {
?>
<div class="alert alert-danger alert-dismissible" role="alert">
    <button type="button" class="close" data-dismiss="alert" aria-label="Close"><span aria-hidden="true">&times;</span></button>
    Warning: Too many sites. <b><?php echo $input_region_num_unique ?></b> sites detected. However we only allow 
    <b><?php echo $limit_site ?></b> sites at one time.
</div>
<?php
        exit(0);
    }
    
    $input_regions = implode("\n", $input_regions_array);
    file_put_contents("$working_dir/perl_input_region.tmp", $input_regions);
    
    // Run Pipeline: Design and Check
    // $db = implode(' ', array_map(function($i){return "../db/$i" ;}, $_POST['select-database']));
    $db = $config['database']."/".$_POST['select-database'];
    $command = "perl pipeline_design_check.pl "
               ."--input=$working_dir/perl_input_region.tmp "
               ."--template=$database_dir/$template_tax "
               ."--region_type=$_POST[region_type] "
               ."--samtools=$path_samtools "
               ."--primer3bin=$path_primer3  "
               ."--primer3setting=$working_dir/p3_settings_file "
               ."--blastn='$path_blastn' "
               ."--blast_e_value=$_POST[blast_e_value] "
               ."--blast_word_size=$_POST[blast_word_size] "
               ."--blast_identity=$_POST[blast_identity] "
               ."--blast_max_hsps=$_POST[blast_max_hsps] "
               ."--checkingdb='$db' "
               ."--checking_size_start=$_POST[size_start] "
               ."--checking_size_stop=$_POST[size_stop] "
               ."--primer_num_retain=$_POST[retain] "
               ."--min_Tm_diff=$_POST[min_Tm_diff] "
               ."--conc_primer=$_POST[conc_primer] "
               ."--conc_Na=$_POST[conc_Na] "
               ."--conc_K=$_POST[conc_K] "
               ."--conc_Tris=$_POST[conc_Tris] "
               ."--conc_Mg=$_POST[conc_Mg] "
               ."--conc_dNTPs=$_POST[conc_dNTPs] "
               ."--outputdir=$working_dir "
               ."--num_cpu=$cpu "
               ."--output_detail "
               ."--product_size_min=$_POST[product_size_min] "
               ."--product_size_max=$_POST[product_size_max] ";
    if ($_POST['use_3_end']==1) {
        $command .= "--use_3end";
    }
    exec($command);
    
    echo file_get_contents("$working_dir/primer.final.result.html");
}
// check Primers Only
else {
    
    // input primers
    $input_primers = stripslashes(strip_tags(trim($_POST['check-primers'])));
    $input_primers_array = array_filter(explode("\n", $input_primers), create_function('$v','return !empty($v);'));
    $input_primers_num = count($input_primers_array);
    $input_primers_array = array_unique($input_primers_array);
    $input_primers_num_unique = count($input_primers_array);
?>
<div class="alert alert-info alert-dismissible" role="alert">
    <button type="button" class="close" data-dismiss="alert" aria-label="Close"><span aria-hidden="true">&times;</span></button>
    <b><?php echo $input_primers_num ?></b> primer group(s) detected; <b><?php echo $input_primers_num_unique ?></b> primer group(s) used
</div>
<?php
    if ($input_primers_num_unique>$limit_primer) {
?>
<div class="alert alert-danger alert-dismissible" role="alert">
    <button type="button" class="close" data-dismiss="alert" aria-label="Close"><span aria-hidden="true">&times;</span></button>
    Warning: Too many primers. <b><?php echo $input_primers_num_unique ?></b> primer groups detected. However we only allow 
    <b><?php echo $limit_primer ?></b> primer groups at one time.
</div>
<?php
        exit(0);
    }
    $input_primers = implode("\n", $input_primers_array);
    file_put_contents("$working_dir/check.only.tmp", $input_primers);
    
    // db
    // $db = implode(' ', array_map(function($i){return "../db/$i" ;}, $_POST['select-database']));
    $db = "$database_dir/".$_POST['select-database'];
    $command = "perl _run_specificity_check.pl "
               ."--input=$working_dir/check.only.tmp "
               ."--db='$db' "
               ."--samtools=$path_samtools "
               ."--blastn=$path_blastn "
               ."--blast_e_value=$_POST[blast_e_value] "
               ."--blast_word_size=$_POST[blast_word_size] "
               ."--blast_identity=$_POST[blast_identity] "
               ."--blast_max_hsps=$_POST[blast_max_hsps] "
               ."--size_start=$_POST[size_start] "
               ."--size_stop=$_POST[size_stop] "
               ."--min_Tm_diff=$_POST[min_Tm_diff] "
               ."--conc_primer=$_POST[conc_primer] "
               ."--conc_Na=$_POST[conc_Na] "
               ."--conc_K=$_POST[conc_K] "
               ."--conc_Tris=$_POST[conc_Tris] "
               ."--conc_Mg=$_POST[conc_Mg] "
               ."--conc_dNTPs=$_POST[conc_dNTPs] "
               ."--outputdir=$working_dir "
               ."--num_cpu=$cpu "
               ."--detail ";
    if ($_POST['use_3_end']==1) {
        $command .= "--use_3end";
    }
    exec($command);
    
    echo file_get_contents("$working_dir/specificity.check.result.html");
}
?>