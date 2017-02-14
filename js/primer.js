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
    $.get('script/db.php', function(data){
        $('[name="select-template"]').append(data);
        $('[name="select-database[]"]').append(data);
        $('[name="select-template"]').append('<optgroup label="Custom"><option value="custom">Custom Template Sequences...</option></optgroup>');
        
        // get all the default values
        var inputs = $(':text.save-input');
        var originalValFor = new Object;
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
    });
    
    // modify reset button to satisfy selector
    $(':reset').click(function(){
        $('[name="select-template"]').selectpicker('val', '');
        $('[name="select-database[]"]').selectpicker('val', ''); 
    });
    
    // Define App type: design OR check
    $('a[data-toggle="tab"]').on('shown.bs.tab', function (e) {
        var type = $(e.target).attr('href').replace('#', '');
        $("[name='app-type']").val(type);
    });

    // Remove flanking blanks after text input
    $(':text').blur(function(){
        var val = $(this).val();
        $(this).val($.trim(val));
    });

    // If users select custom template, then showing custom template FASTA sequence input textarea
    $('[name="select-template"]').on('changed.bs.select', function (event, clickedIndex, newValue, oldValue) {
        if (event.target.value=='custom') {
            $('[name="custom-template-sequences"]').parent().removeClass('hidden');
        }
        else {
            $('[name="custom-template-sequences"]').parent().addClass('hidden');
        }
    });

    // form validation & submit
    function ScrollToResult() {
        $('html,body').animate({
            scrollTop: $('#result').offset().top,
        }, 1000);
    };
    function AjaxSubmit() {
        var options = { 
            target: '#result',   // target element(s) to be updated with server response 
            //url: 'script/primer.php',
            url: 'test.php', // test only
            beforeSubmit: ScrollToResult,
            success: ScrollToResult,
        }; 
        
        $('#result').removeClass('hidden').html('<span class="fa fa-spinner fa-spin fa-4x"></span>');
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
        $.get('script/modal.php', {file: fileName}, function(data) {
            modal.find('.modal-body .fa-spinner').addClass('hidden');
            modal.find('.modal-body pre').html(data);
        });
    })
    
    // test Only
    //$('#test').load('script/specificity.check.result.html');
});


