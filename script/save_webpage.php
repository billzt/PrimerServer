<?php

session_start();
$session_id = session_id();
$date = date("Y-m-d");
$time = date("H-i-s");
$print_time = str_replace('-', ':', $time);
$time_diff = date("P");
$working_dir = "/tmp/Primer-$date-$session_id";
$file = $_GET['type1']=='design' ? 'primer.final.result.html' : 'specificity.check.result.html';
$region_type = $_GET['type2'];

$result = file_get_contents("$working_dir/$file");

$html = <<<END
<!doctype html>
<html lang="en">
    <head>
        <title> PrimerServer Result: $date $print_time</title>
        <meta charset="utf-8">
        <meta http-equiv="X-UA-Compatible" content="IE=edge">   <!-- For IE -->
        <meta name="renderer" content="webkit">   <!-- For some Chinese web browser -->
        <meta name="viewport" content="width=device-width, initial-scale=1"> <!-- For mobile device -->
        <meta name="Author" content="">
        <meta name="Keywords" content="">
        <meta name="Description" content="">
        <link rel="shortcut icon" type="image/x-icon" href="favicon.ico"/>
        
        <!-- Bootstrap CSS -->
        <link rel="stylesheet" href="../css/bootstrap.min.css" >
        <!-- Bootstrap-Select plugin CSS -->
        <link rel="stylesheet" href="../css/bootstrap-select.min.css" >
        <!-- Bootstrap Table plugin CSS -->
        <link rel="stylesheet" href="../css/bootstrap-table.min.css"  >
        
        <!-- font-awesome CSS -->
        <link rel="stylesheet" href="../css/font-awesome.min.css">
        
        <!-- JQuery Validation CSS -->
        <link rel="stylesheet" href="../css/validationEngine.jquery.css" />
        
        <link rel="stylesheet" href="../css/gh-fork-ribbon.min.css" />
        
        <!-- Own CSS -->
        <link rel="stylesheet" href="../css/style.css">
    </head>
    <body>
        <div class="container" role="main">
            <h1>PrimerServer Result: $date $print_time (GMT $time_diff)</h1>
            <div id="region_type">
                <div class="radio">
                    <label><input type="radio" name="region_type" value="SEQUENCE_TARGET" disabled />Target Region</label>
                </div>
                <div class="radio">
                    <label><input type="radio" name="region_type" value="SEQUENCE_INCLUDED_REGION" disabled />Include Region</label>
                </div>
                <div class="radio">
                    <label><input type="radio" name="region_type" value="FORCE_END" disabled />Force 3' End</label>
                </div>
            </div>
            <div class="row">
                <div id="result">
                    $result
                </div>
            </div>
        </div>
        
        <!-- jQuery -->
        <script src="../js/jquery.min.js"></script>
        <!-- Bootstrap JS -->
        <script src="../js/bootstrap.min.js"></script>
        <!-- Bootstrap Select JS -->
        <script src="../js/bootstrap-select.min.js"></script>
        <!-- Bootstrap Table JS -->
        <script src="../js/bootstrap-table.min.js"></script>
        <!-- jQuery Validation -->
        <script src="../js/jquery.validationEngine.min.js"></script>
        <script src="../js/jquery.validationEngine-en.js"></script>
        <!-- jQuery Saves Form State -->
        <script src="../js/jquery.phoenix.min.js"></script>
        <!-- D3 -->
        <script src="../js/d3.v4.min.js"></script>
        <!-- SVG zoom -->
        <script src="../js/svg-pan-zoom.min.js"></script>
        <!-- JQuery Timer -->
        <script src="../js/jquery.timer.js"></script>
        <!-- File Download -->
        <script src="../js/FileSaver.min.js"></script>
        <!-- Virtual electrophoresis -->
        <script src="../js/d3-electrophoresis.js"></script>
        <!-- Own JS -->
        <script src="../js/primer.js"></script>
        
END;

if ($_GET['type1']=='design') {
    $html .= <<<END
<script>
    $(function () {
        $('[value="$region_type"]').prop('checked',true);
        GenerateGraph($('#site-1'));
        $('#primers-result').find('.collapse').on('shown.bs.collapse', function (e) {
            GenerateGraph($(this));
        });
        $('#primers-result').find('.collapse').on('hidden.bs.collapse', function (e) {
            $(this).find('.PrimerFigure').html('');
            $(this).find('.PrimerFigureControl').remove();
        });
    });
</script>
END;
}
else {
    $html .= <<<END
<script>
    $(function () {
        $('#region_type').addClass('hidden');
    });
</script>
END;
}

$html .= <<<END
<script>
    $(function () {
        $('[data-toggle="modal"]').addClass('hidden');
    });
</script>
    </body>
</html>
END;

file_put_contents("../save/PrimerServer.$date.$time.$session_id.html", $html);

echo "PrimerServer.$date.$time.$session_id.html";
