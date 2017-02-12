// actions after document ready
$(function () {
    // Tooltip for bootstrap
    $('[data-toggle="tooltip"]').tooltip({html: true});
    $('[data-toggle="popover"]').popover({html: true});
    $('[data-toggle="table"]').on('post-body.bs.table', function () {
        $('[data-toggle="tooltip"]').tooltip({
            container: 'body'
        });
    });


    // test Only
    //$('#test').load('script/primer.final.result.html');
});

// Define App type: design OR check
$('a[data-toggle="tab"]').on('shown.bs.tab', function (e) {
    var type = $(e.target).attr('href').replace('#', '');
    $("[name='app-type']").val(type);
});

// remove flanking blanks after text input
$(':text').blur(function(){
    var val = $(this).val();
    $(this).val($.trim(val));
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
        url: 'script/primer.php',
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
