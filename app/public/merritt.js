$(document).ready(function() {
  $("table.data a").on("click", function() {
    if ($(this).hasClass('button-disabled')) {
      return false;
    }
  });
  $("#semantic").on("click", function() {
    $("table.data tr.data").show();
    if ($("#semantic:checked").is("*")) {
      $("table.data tr.other").hide();
    } 
  });
});