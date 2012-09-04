//= require jquery
//= require jquery_ujs
//= require jquery-ui-1.8.23.custom.min
//= require chosen.jquery
//= require jquery.jeditable
//= require ckeditor-jquery
//= require ckeditor/jquery.generateId
//= require ckeditor/jquery.jeditable.ckeditor


(function($){

  $.fn.outerHTML = function() {
    return $(this).clone().wrap('<p></p>').parent().html();
  }

  $(document).ready(function(){

    CKEDITOR.config.toolbar_Basic = [[ 'Source', '-', 'Bold', 'Italic' ] ];
    CKEDITOR.config.toolbar_full = [ ['Cut','Copy','Paste','PasteText','PasteFromWord'],
                                     ['Bold','Italic','Underline','Strike'],
                                     ['Format','-','NumberedList','BulletedList','Blockquote'],
                                     ['Link','Unlink','Anchor','-','SelectAll','RemoveFormat'],
                                     ['Source','ShowBlocks','Maximize'],
                                     ['Button','Button','linkItem'] ]
    //CKEDITOR.config.menu_groups = 'googlemaps';
    CKEDITOR.config.extraPlugins = 'linkItem';
   // CKEDITOR.config.toolbar_map = [ ['Button','Button','linkItem'] ];

    $('select.chosen').chosen();

    $('.jquery-ckeditor').ckeditor(
        {
      toolbar:'full'
    }
    );

    $('.sortable').sortable({
      update: function(e, ui){
        var $target        = $(e.target).closest('ol'),
            orderedItems   = {},
            resourceURL    = $target.attr('data-resource'),
            childTag       = $target.children().first()[0].nodeName.toLowerCase(),
            primaryLabel   = $target.attr('data-primary-label'),
            secondaryLabel = $target.attr('data-secondary-label');
        $(childTag, $(e.target).closest('ol')).each(function(index, element){
          var objectId = $(element).attr('data-id');
          orderedItems[objectId] = (index + 1);
        });
        $.ajax({
          type: 'POST',
          url: resourceURL,
          data: {collection: orderedItems},
          success: function(data, statusCode){
            if (childTag == 'li'){
              $target.effect('highlight', {}, 1500);
            } else {
              $target.parents('fieldset').effect('highlight', {}, 1500);
            }
            if (primaryLabel !== undefined){
              $('td.label', $target).text(secondaryLabel);        // This could be implemented better
              $('td.label', $target).first().text(primaryLabel);  //
            }
          }
        });
      }
    });

    $('.add_description').click(function(){
        var $this = $(this);
        $this.parent()
          .children('.description')
          .slideToggle(300, function(){
            if ($this.text() == 'Add Description'){
              $this.text('Hide Description');
            }else{
              $this.text('Add Description');
            }
          });
    });

    $("a.destroy_description", this).live("click", function(e) {
       var $descNode = $(this).closest('dl')
       var url = $(this).attr('action');
       $.ajax({
         type: "DELETE",
         url: url,
         dataType: "html",
         beforeSend: function() {
   			$descNode.animate({'backgroundColor':'#fb6c6c'},300);
         },
         success: function() {
           $descNode.slideUp(300,function() {
             $descNode.remove();
           });
         }
       });
    });

    $("a.remove_featured", this).live("click", function(e) {
       var $docNode = $(this).closest('div.document')
       var url = $(this).attr('action');
       $.ajax({
         type: "POST",
         url: url,
         dataType: "html",
         beforeSend: function() {
   			$docNode.animate({'backgroundColor':'#fb6c6c'},300);
         },
         success: function(data) {
           $docNode.slideUp(300,function() {
             $docNode.remove();
           });
           //$("#show-selected").before('<div id="flash_notice"> data </div>'); // This could be implemented better
         }
       });
    });

    $('.edit-text').editable(submitEditableText,{
         indicator : 'Saving...',
         tooltip   : 'Click to edit...'
    });

    function submitEditableText(value, settings) {
       var edits = new Object();
       var result = value;
       edits[settings.name] = [value];
       var params = $('div.edit-text').attr("data-column-name")+"="+value;
        var returned = $.ajax({
         type: "PUT",
         url: $('div.edit-text').attr("data-update-uri"),
         dataType: "html",
         data: params,
         success: function(data){
           $(".div.edit-text").text(value)
         },
         error: function(xhr, textStatus, errorThrown){
     		$.noticeAdd({
             inEffect:               {opacity: 'show'},      // in effect
             inEffectDuration:       600,                    // in effect duration in milliseconds
             stayTime:               6000,                   // time in milliseconds before the item has to disappear
             text:                   'Your changes failed'+ xhr.statusText + ': '+ xhr.responseText,
             stay:                   true,                  // should the notice item stay or not?
             type:                   'error'                // could also be error, success
            });
         }
      });
      return value;
    }

    function submitEditableTextArea(value, settings) {
       var edits = new Object();
       var result = value;
       edits[settings.name] = [value];
       var params = $('div.edit-textarea').attr("data-column-name")+"="+value;
        var returned = $.ajax({
         type: "PUT",
         url: $('div.edit-textarea').attr("data-update-uri"),
         dataType: "html",
         data: params,
         success: function(data){
           $(".div.edit-text").text(value)
         },
         error: function(xhr, textStatus, errorThrown){
     		$.noticeAdd({
             inEffect:               {opacity: 'show'},      // in effect
             inEffectDuration:       600,                    // in effect duration in milliseconds
             stayTime:               6000,                   // time in milliseconds before the item has to disappear
             text:                   'Your changes failed'+ xhr.statusText + ': '+ xhr.responseText,
             stay:                   true,                  // should the notice item stay or not?
             type:                   'error'                // could also be error, success
            });
         }
      });
      return value;
    }

    $('.edit-textarea').editable(submitEditableTextArea, {
          method    : "PUT",
          type      : "ckeditor",
          submit    : "OK",
          cancel    : "Cancel",
          placeholder : "click to edit description",
          onblur    : "ignore",
          name      : "textarea",
          id        : "field_id",
          indicator : 'Saving...',
          tooltip   : 'Click to edit...',
          height    : "100",
          ckeditor  : { toolbar:'full'
                      }
    });

    $("div.content").hide();

    $("a.heading").click(function(){
        $(this).siblings(".intro").toggle()
        $(this).next("div.content").slideToggle(300);
        $(this).text($(this).text() == '[Read the complete essay]' ? '[Hide essay]' : '[Read the complete essay]');
    });

    $("div.ckeditor h3.index_title a").click( function(){
      var href = $(this).attr('href');
      var dialog = window.opener.CKEDITOR.dialog.getCurrent();
      var parent = window.opener.document;
      dialog.setValueOf('info','url',href);  // Populates the URL field in the Links dialogue.
      dialog.setValueOf('info','protocol','');  // This sets the Link's Protocol to Other which loads the file from the same folder the link is on
      dialog.setValueOf('info','displayField',$(this).html());  // Populates the display field in the Links dialogue
      window.close(); // closes the popup window
      return false;
    });

    $(".add_description h3.index_title a").click( function(){
      var href = $(this).attr('href');
      alert(href)
       $.ajax({
         type: "GET",
         url: url,
         dataType: "html",
         beforeSend: function() {
   			$descNode.animate({'backgroundColor':'#fb6c6c'},300);
         },
         success: function() {
           $descNode.slideUp(300,function() {
             $descNode.remove();
           });
         }
       });
      return false;
    });

  });
})(jQuery);
