<?php

function reportmsg($msg) {
?>
<div class="row">
    <div class="alert alert-danger alert-dismissible" role="alert">
        <button type="button" class="close" data-dismiss="alert" aria-label="Close"><span aria-hidden="true">&times;</span></button>
        <?php echo $msg, " Please change your Parameters and run it again" ?>
    </div>
</div>
<?php
}

$msg = '';
if ($_POST['PRIMER_OPT_SIZE']<$_POST['PRIMER_MIN_SIZE'] or $_POST['PRIMER_OPT_SIZE']>$_POST['PRIMER_MAX_SIZE']) {
    $msg = "Error: PRIMER_OPT_SIZE(<strong>$_POST[PRIMER_OPT_SIZE]</strong>) is not between 
    PRIMER_MIN_SIZE(<strong>$_POST[PRIMER_MIN_SIZE]</strong>) and PRIMER_MAX_SIZE(<strong>$_POST[PRIMER_MAX_SIZE]</strong>).";
    reportmsg($msg);
    exit(0);
}

if ($_POST['PRIMER_OPT_GC_PERCENT']<$_POST['PRIMER_MIN_GC'] or $_POST['PRIMER_OPT_GC_PERCENT']>$_POST['PRIMER_MAX_GC']) {
    $msg = "Error: PRIMER_OPT_GC_PERCENT(<strong>$_POST[PRIMER_OPT_GC_PERCENT]</strong>) is not between 
    PRIMER_MIN_GC(<strong>$_POST[PRIMER_MIN_GC]</strong>) and PRIMER_MAX_GC(<strong>$_POST[PRIMER_MAX_GC]</strong>).";
    reportmsg($msg);
    exit(0);
}

if ($_POST['PRIMER_OPT_TM']<$_POST['PRIMER_MIN_TM'] or $_POST['PRIMER_OPT_TM']>$_POST['PRIMER_MAX_TM']) {
    $msg = "Error: PRIMER_OPT_TM(<strong>$_POST[PRIMER_OPT_TM]</strong>) is not between 
    PRIMER_MIN_TM(<strong>$_POST[PRIMER_MIN_TM]</strong>) and PRIMER_MAX_TM(<strong>$_POST[PRIMER_MAX_TM]</strong>).";
    reportmsg($msg);
    exit(0);
}

if ($_POST['PRIMER_MAX_SELF_ANY_TH']>$_POST['PRIMER_MIN_TM']-10) {
    $msg = "Error: PRIMER_MAX_SELF_ANY_TH(<strong>$_POST[PRIMER_MAX_SELF_ANY_TH]</strong>) is too high. 
    It must be at least 10 &deg;C lower than PRIMER_MIN_TM(<strong>$_POST[PRIMER_MIN_TM]</strong>).";
    reportmsg($msg);
    exit(0);
}

if ($_POST['PRIMER_PAIR_MAX_COMPL_ANY_TH']>$_POST['PRIMER_MIN_TM']-10) {
    $msg = "Error: PRIMER_PAIR_MAX_COMPL_ANY_TH(<strong>$_POST[PRIMER_PAIR_MAX_COMPL_ANY_TH]</strong>) is too high. 
    It must be at least 10 &deg;C lower than PRIMER_MIN_TM(<strong>$_POST[PRIMER_MIN_TM]</strong>).";
    reportmsg($msg);
    exit(0);
}

if ($_POST['PRIMER_MAX_SELF_END_TH']>$_POST['PRIMER_MIN_TM']-10) {
    $msg = "Error: PRIMER_MAX_SELF_END_TH(<strong>$_POST[PRIMER_MAX_SELF_END_TH]</strong>) is too high. 
    It must be at least 10 &deg;C lower than PRIMER_MIN_TM(<strong>$_POST[PRIMER_MIN_TM]</strong>).";
    reportmsg($msg);
    exit(0);
}

if ($_POST['PRIMER_PAIR_MAX_COMPL_END_TH']>$_POST['PRIMER_MIN_TM']-10) {
    $msg = "Error: PRIMER_PAIR_MAX_COMPL_END_TH(<strong>$_POST[PRIMER_PAIR_MAX_COMPL_END_TH]</strong>) is too high. 
    It must be at least 10 &deg;C lower than PRIMER_MIN_TM(<strong>$_POST[PRIMER_MIN_TM]</strong>).";
    reportmsg($msg);
    exit(0);
}

if ($_POST['PRIMER_MAX_HAIRPIN_TH']>$_POST['PRIMER_MIN_TM']-10) {
    $msg = "Error: PRIMER_MAX_HAIRPIN_TH(<strong>$_POST[PRIMER_MAX_HAIRPIN_TH]</strong>) is too high. 
    It must be at least 10 &deg;C lower than PRIMER_MIN_TM(<strong>$_POST[PRIMER_MIN_TM]</strong>).";
    reportmsg($msg);
    exit(0);
}

if ($_POST['retain']>$_POST['PRIMER_NUM_RETURN']) {
    $msg = "Error: Max. Primers Return Number(<strong>$_POST[retain]</strong>) is larger 
    than Primer3's PRIMER_NUM_RETURN(<strong>$_POST[PRIMER_NUM_RETURN]</strong>).";
    reportmsg($msg);
    exit(0);
}