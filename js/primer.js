$(function () {
    
    // Tooltip for bootstrap
    $('[data-toggle="tooltip"]').tooltip({html: true});
    $('[data-toggle="popover"]').popover({html: true});
    $('[data-toggle="table"]').on('post-body.bs.table', function () {
        $('[data-toggle="tooltip"]').tooltip({
            container: 'body'
        });
    });
    
    // footer year
    var date = new Date();
    $('#current-year').html(date.getFullYear());
    
    // select template: options
    var originalValFor = new Object;
    $.get('script/db.php', function(data){
        $('[name="select-template"]').append(data);
        $('[name="select-database[]"]').append(data);
        $('[name="select-template"]').append('<optgroup label="Custom"><option value="custom">Custom Template Sequences...</option></optgroup>');
        
        // get all the default values
        var inputs = $(':text.save-input');
        for (var i=0; i<inputs.length; i++) {
            var el = inputs[i];
            originalValFor[el.name] = el.defaultValue;
        }

        // Load user's last saved inputs
        $('.save-input').phoenix({
            saveInterval: 1000,
        });
        $('[name="select-template"]').selectpicker('refresh'); 
        $('[name="select-database[]"]').selectpicker('refresh');
        
        // Highlight Changed Field
        for (var i=0; i<inputs.length; i++) {
            var el = inputs[i];
            if (el.value!=originalValFor[el.name]) {
                $(el).css('background-color', '#ffffbf');
            }
        }
        
        // Highlight Changed Field after users' input
        $(inputs).blur(function(){
            for (var i=0; i<inputs.length; i++) {
                var el = inputs[i];
                if (el.value!=originalValFor[el.name]) {
                    $(el).css('background-color', '#ffffbf');
                }
                else {
                    $(el).css('background-color', 'white');
                }
            }
        })
        
        // In help modal, list IDs (After the options completely loaded)
        var options = $('[name="select-template"] option');
        for (var i=0; i<options.length; i++) {
            var option_val = $(options[i]).val();
            if (option_val!='' && option_val!='custom') {
                var option_text = $(options[i]).html();
                $('#help-modal-ID-list').append('<a href="script/modal_help_list_ID.php?file='+option_val+'" class="list-group-item">'
                +option_text+' <span class="glyphicon glyphicon-download"></span></a>');
            }
        }
        
        // App type: design OR check
        // when the document is ready, show the last App type select by users
        $('a[href="#'+$("[name='app-type']").val()+'"]').tab('show');
        
        // Paramter panel collapse
        if ($("[name='parameter-design']").val()=='hide') {
            $('#parameter-design').collapse('hide');
        }
        else {
            $('#parameter-design').collapse('show');
        }
        if ($("[name='parameter-check']").val()=='hide') {
            $('#parameter-check').collapse('hide');
        }
        else {
            $('#parameter-check').collapse('show');
        }
    });
    
    
    // modify reset button to satisfy selector
    $(':reset').click(function(){
        $('[name="select-template"]').selectpicker('val', '');
        $('[name="select-database[]"]').selectpicker('val', ''); 
    });
    
    // change App type when user change it
    $('a[data-toggle="tab"]').on('shown.bs.tab', function (e) {
        var type = $(e.target).attr('href').replace('#', '');
        $("[name='app-type']").val(type);
    });
    
    // change panel collapse state when user change it
    $('#parameter-design').on('shown.bs.collapse', function(){
        $("[name='parameter-design']").val('show');
    });
    $('#parameter-design').on('hidden.bs.collapse', function(){
        $("[name='parameter-design']").val('hide');
    });
    $('#parameter-check').on('shown.bs.collapse', function(){
        $("[name='parameter-check']").val('show');
    });
    $('#parameter-check').on('hidden.bs.collapse', function(){
        $("[name='parameter-check']").val('hide');
    });
    
    // Remove flanking blanks after text input; If it is blank, fill original value for it
    $(':text').blur(function(){
        var val = $.trim($(this).val());
        if (val!='') {
            $(this).val(val);
        }
        else {
            var el = $(this);
            $(this).val(originalValFor[el[0].name]);
        }
    });

    // If users select (Or inintially load) custom template, then showing custom template FASTA sequence input textarea
    $('[name="select-template"]').on('changed.bs.select refreshed.bs.select', function (event, clickedIndex, newValue, oldValue) {
        if (event.target.value=='custom') {
            $('[name="custom-template-sequences"]').parent().removeClass('hidden');
        }
        else {
            $('[name="custom-template-sequences"]').parent().addClass('hidden');
        }
    });
    
    /***************** Complex functions to display Figure after showing Panel, used after the server return results */
    function getMaxOfArray(numArray) {
        return Math.max.apply(null, numArray);
    }
    function getMinOfArray(numArray) {
        return Math.min.apply(null, numArray);
    }
    function GenerateGraph(el) {
        // empty the element
        el.find('.PrimerFigure').html('');
        
        // svg
        var svg = d3.select(el.find('.PrimerFigure')[0])
                    .append('svg')
                    .attr('width', '100%');
        
        // primers regions
        var primers = el.find('.list-group-item');
        var primers2region = new Object;
        var primers2hit = new Object;
        var allPoses = new Array;
        for (var i=0; i<primers.length; i++) {
            var id = $(primers[i]).find('.list-group-item-heading').attr('id');
            var primer_left = $(primers[i]).find('.primer-left-region');
            var primer_right = $(primers[i]).find('.primer-right-region');
            var region_1 = $(primer_left[0]).html().split('-');
            var region_2 = $(primer_right[0]).html().split('-');
            primers2region[id] = [region_1, region_2];
            Array.prototype.push.apply(allPoses, region_1);
            Array.prototype.push.apply(allPoses, region_2);
            var hitNum = $(primers[i]).find('.hit-num').data('hit');
            primers2hit[id] = hitNum;
        }
        
        // axis
        var axisStart = getMinOfArray(allPoses);
        var axisEnd = getMaxOfArray(allPoses);
        var axisScale = d3.scale.linear().domain([axisStart, axisEnd]).range([0, 1000]);
        var axis = d3.svg.axis().scale(axisScale).orient('top').ticks(10);
        svg.append('g').attr('class', 'axis').call(axis); // axis: translate(x,y) is no longer needed as PanZoom can do it
        
        // Text
        var template = el.prev().find('.site-detail').data('seq');
        svg.append('text').attr('x','0').attr('y','-30').text('Template '+template).attr('font-size', '120%');
        
        // target region
        var targetPos = el.prev().find('.site-detail').data('pos');
        var targetLen = el.prev().find('.site-detail').data('length');
        var rectHight = 30;
        svg.append('rect').attr('x', axisScale(targetPos))  
           .attr('y', -rectHight/2)  // axis:y-rect:height/2
           .attr('width', axisScale(targetPos+targetLen)-axisScale(targetPos)).attr('height', rectHight)
           .attr("fill", "none").attr('stroke', 'red').attr('stroke-width', '3');
        
        // Primer Group
        var colorScale = d3.scale.linear().domain([1, 100]).range([0, 32]);
        function AddPrimer(LprimerStart, LprimerEnd, RprimerStart, RprimerEnd, i, h, id) {
            var primerGroup = svg.append('a').attr('xlink:href','#'+id).attr('class', 'primerGroup')
                            .attr('title', 'Primer '+i).append('g');
            var baseY = rectHight+30*(i-1);
            var lineFunction = d3.svg.line()
                .x(function(d) { return Math.round(axisScale(d.x)); })
                .y(function(d) { return d.y; })
                .interpolate("linear");
            var color = 'rgb('+Math.round(colorScale(h)*8)+','+Math.round(colorScale(h)*8)+','+Math.round(colorScale(h)*8)+')';
            
            // Left Primer
            var Llength = LprimerEnd-LprimerStart+1;
            
            var LlineData = [ { "x": LprimerStart, "y": baseY-5},  { "x": LprimerStart+Math.round(Llength/3*2), "y": baseY-5},
                             { "x": LprimerStart+Math.round(Llength/3*2), "y": baseY-10}, {"x": LprimerEnd, "y": baseY},
                             { "x": LprimerStart+Math.round(Llength/3*2), "y": baseY+10}, {"x": LprimerStart+Math.round(Llength/3*2), "y": baseY+5},
                             { "x": LprimerStart, "y": baseY+5},  { "x": LprimerStart, "y": baseY-5}];
            
            primerGroup.append('path').attr('d', lineFunction(LlineData)).attr("fill", color).attr('stroke', color);
            
            
            // Right Primer
            var Rlength = RprimerEnd-RprimerStart+1;
            
            var RlineData = [ {"x": RprimerStart, "y": baseY}, {"x": RprimerStart+Math.round(Rlength/3*1), "y": baseY-10},
                              {"x": RprimerStart+Math.round(Rlength/3*1), "y": baseY-5}, {"x": RprimerEnd, "y": baseY-5},
                              {"x": RprimerEnd, "y": baseY+5}, {"x": RprimerStart+Math.round(Rlength/3*1), "y": baseY+5},
                              {"x": RprimerStart+Math.round(Rlength/3*1), "y": baseY+10}, {"x": RprimerStart, "y": baseY}];
            primerGroup.append('path').attr('d', lineFunction(RlineData)).attr("fill", color).attr('stroke', color);
            
            // Center Line
            var LineData = [{"x": LprimerEnd, "y": baseY}, {"x": RprimerStart, "y": baseY}];
            primerGroup.append('path').attr('d', lineFunction(LineData)).attr("fill", color).attr('stroke', color);
                          
        }

        var primerRank = 1;
        for ( id in primers2region) {
            var LprimerStart=primers2region[id][0][0];
            var LprimerEnd=primers2region[id][0][1];
            var RprimerStart=primers2region[id][1][0];
            var RprimerEnd=primers2region[id][1][1];
            var h = primers2hit[id];
            AddPrimer(LprimerStart*1, LprimerEnd*1, RprimerStart*1, RprimerEnd*1, primerRank*1, h*1, id);
            primerRank++;
            //break;
        }
        
        // extend svg height if there are too many primers
        if (primerRank>3) {
            svg.attr('height', (primerRank-3)*30+150);
        }
        
        // Pan and Zoom
        if ($('.PrimerFigure svg').length>0) {
            var zoomObj = svgPanZoom('.PrimerFigure svg');
            $(window).resize(function(){
                zoomObj.resize();
                zoomObj.fit();
                zoomObj.center();
            });            
        }
        
        // tooltip
        $(".primerGroup").tooltip({
            'container': 'body',
        });
    }
    
    /***************** Complex functions finished  ***********************************************************/

    // form validation & submit
    function ScrollToResult() {
        $('html,body').animate({
            scrollTop: $('#result').offset().top,
        }, 1000);
    };
    function AjaxSubmit() {
        var options = { 
            target: '#result',   // target element(s) to be updated with server response 
            url: 'script/primer.php',
            success: function () {
                $('#running-modal').modal('hide');
                ScrollToResult();
                // call Complex functions if we are in design & check mode
                if ($('[name="app-type"]').val()=='design') {
                    GenerateGraph($('#site-1'));
                    $('#primers-result').find('.collapse').on('shown.bs.collapse', function (e) {
                        GenerateGraph($(this));
                    });
                    $('#primers-result').find('.collapse').on('hidden.bs.collapse', function (e) {
                        $(this).find('.PrimerFigure').html('');
                    });                    
                }

                // show download area
                if ($('#primers-result').length>0) {
                    $('#download-primer').removeClass('hidden');
                }
                else {
                    $('#download-primer').addClass('hidden');
                }
            }
        }; 
        
        $('#running-modal .modal-body h4').html('<span class="fa fa-spinner fa-spin fa-4x"></span>');
        $('#running-modal .progress-bar').css('width', '0%').html('');
        $('#running-modal').modal('show');
        $('#form-primer').ajaxSubmit(options);
    };
    $('#form-primer').validationEngine('attach', {
        autoHidePrompt: true,
        autoHideDelay: 5000,
        onValidationComplete: function(form, status) {
            if (status) {
                AjaxSubmit();
            }
        }
    });

    // Showing MFEPrimer result in modal dynamically by Ajax 
    $('#specificity-check-modal').on('show.bs.modal', function (event) {
        var button = $(event.relatedTarget); // Button that triggered the modal
        var fileName = button.data('whatever');
        var modal = $(this);
        $.get('script/modal_MFEPrimer_result.php', {file: fileName}, function(data) {
            modal.find('.modal-body .fa-spinner').addClass('hidden');
            modal.find('.modal-body pre').html(data);
        });
    })
    
    // When running, showing a progress bar
    var timer = $.timer(function(){
        $.get('script/modal_progress.php', function(data) {
            var progress_data = JSON.parse(data); // total, finished, percent
            if (progress_data.total>0) {
                $('#running-modal .modal-body h4').html(progress_data.total+' Primers generated');
                $('#running-modal .progress-bar').css('width', progress_data.percent+'%').html(progress_data.finished+' Primers finished');
                if (progress_data.percent>=100) {
                    timer.stop();
                    $('.progress-bar').removeClass('active').html('Completed');
                }                    
            }
        });
    });
    $('#running-modal').on('shown.bs.modal', function(){
        timer.set({ time : 1000, autostart : true });
    });
    $('#running-modal').on('hidden.bs.modal', function(){
        timer.stop();
    });
    
    // Download primers from Web UI
    // Check whether user input is good
    $('#download-primer input').blur(function(){
        var max_hit = $(this).val();
        if (parseInt(max_hit,10)==max_hit) {
            $('#download-primer button').prop('disabled', false);
        }
        else {
            $('#download-primer button').prop('disabled', true);
        }
    });
    $('#download-primer button').click(function(){
        // Get User Input
        var max_hit = $('#download-primer input').val();
        
        var download_text = "#Site_ID\tPrimer_Rank\tPenalty_Score\tHit_Num\tPrimers\n";
        var sites = $('#primers-result .panel');
        for (var i=0; i<sites.length; i++) {
            var site_id = $(sites[i]).find('.panel-heading').find('small');
            var primers = $(sites[i]).find('.panel-body').find('.list-group-item');
            for (var j=0; j<primers.length; j++) {
                // deside whether to print this ID or not
                var hit_num = $(primers[j]).find('.hit-num').data('hit');
                if (hit_num>max_hit) {
                    continue;
                }
                
                // print site ID
                if (site_id.data('seq')) {
                    download_text += site_id.data('seq')+'-'+site_id.data('pos')+'-'+site_id.data('length')+"\t";
                }
                else {
                    download_text += site_id.html() + "\t";
                }
                
                // print primers
                var primer_id = $(primers[j]).find('.list-group-item-heading').html();
                var primer_seqs = $(primers[j]).find('.list-group-item-text').find('.monospace-style');
                var penalty = $(primers[j]).find('.penalty');
                
                download_text += primer_id + "\t";
                if (penalty.length>0) {
                    download_text += penalty.html() + "\t";
                }
                else {
                    download_text += "\t";
                }
                download_text += hit_num + "\t";
                for (var k=0; k<primer_seqs.length; k++) {
                    download_text += $(primer_seqs[k]).html() + "\t";
                }
                download_text += "\n";
            }
        }
        var blob = new Blob([download_text], {type: "text/plain;charset=utf-8"});
        saveAs(blob, "primer.list.txt"); 
    });
    
    //$('#test').load('primer.final.result.html');
});


