$(document).ready(function() {
  // Allow links to be disabled in table displays
  $("table.data a").on("click", function() {
    if ($(this).hasClass('button-disabled')) {
      return false;
    }
  });

  $("input.filter:checkbox").on("click", function() {
    if ($(this).attr('match') == 'true') {
      $("table.data tr.data").show();
      $("input.filter:checkbox:checked").each(function() {
        $("table.data tr.data").hide();
        $("table.data tr." + $(this).val()).show();
      });   
    } else {
      $("table.data tr.data").show();
      $("input.filter:checkbox:checked").each(function() {
        $("table.data tr." + $(this).val()).hide();
      });   
    }
  });
});