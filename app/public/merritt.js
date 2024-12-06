$(document).ready(function() {
  $("#semantic").on("click", function() {
    $("#semantic:checked").is("*") ? $("tr.other").hide() : $("tr.other").show();
  });
});