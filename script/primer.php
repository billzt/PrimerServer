<?php

// Generate random session directory
session_start();
$session_id = session_id();
$working_dir = "../tmp/$session_id";
if (!file_exists($working_dir)) {
    mkdir($working_dir);
}

// App type
$type = $_POST['app-type'];

// Program Path
$config = parse_ini_file("../config.ini");
$path_samtools = $config['samtools'];
$path_primer3 = $config['primer3'];
$path_pypy = $config['pypy'];

// design & check Primers
if ($type=='design') {
    
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
        file_put_contents("../db/custom", $_POST['custom-template-sequences']);
        // check whether file custom is a DNA FASTA format file
        exec("$path_samtools faidx ../db/custom");
        if (!file_exists('../db/custom.fai')) {  // index FASTA is not OK
?>
<div class="alert alert-danger" role="alert">
    Error: Building index of your input FASTA failed! Either your input sequences are not in FASTA
    format or there are some error in this web setting.
</div>

<?php
            exit(0);
        }
    }
    
    //  input region 
    $input_regions = stripslashes(strip_tags(trim($_POST['template-regions'])));
    $input_regions_array = array_filter(explode("\n", $input_regions), create_function('$v','return !empty($v);'));
    $input_region_num = count($input_regions_array);
    $input_regions_array = array_unique($input_regions_array);
    $input_region_num_unique = count($input_regions_array);
    $input_regions = implode("\n", $input_regions_array);
    file_put_contents("$working_dir/perl_input_region.tmp", $input_regions);
    
    // Run primer3, generate [primer3output.txt] and [primer3output.simple.table.txt]
    $command = "perl run_primer3.pl --input=$working_dir/perl_input_region.tmp "
               ."--db=../db/$template_tax --primer3setting=$working_dir/p3_settings_file "
               ."--primer3bin=$path_primer3 --samtools=$path_samtools "
               ."--outputdir=$working_dir";
    exec($command);
    
    // Run MFEPrimer, generate [specificity.check.result.txt]
    $command = "perl run_specificity_check.pl --input=$working_dir/primer3output.simple.table.txt "
               ."--db=../db/Ghir.NAU.genomic --pypy=$path_pypy --outputdir=$working_dir --size_start=$_POST[size_start] --size_stop=$_POST[size_stop]";
    exec($command);
    
    // Retrieve Results, generate [primer.final.result.html]
    $command = "perl run_final_selection.pl --primer3result=$working_dir/primer3output.txt "
              ."--specificity=$working_dir/specificity.check.result.txt --detail=1 --retain=$_POST[retain] "
              ."--outputdir=$working_dir";
    exec($command);
    
    echo file_get_contents("$working_dir/primer.final.result.html");
}


?>