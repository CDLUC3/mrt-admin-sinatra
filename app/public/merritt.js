$(document).ready(function() {
  $("#semantic").on("click", function() {
    $("table.data tr.data").show();
    if ($("#semantic:checked").is("*")) {
      $("table.data tr.other").hide();
    } 
  });
});