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

  $("select.filter").each(function() {
    var sel = $(this);
    var v = $(this).attr('data');
    vals = {}
    $("td."+v).each(function() {
      var value = $(this).text();
      vals[value] = value in vals ? vals[value] + 1 : 1;
    });
    $.each(vals, function(key, value) {
      sel.append($("<option/>").attr("value", key).text(key + " (" + value + ")"));
    });
    sel.on("change", function() {
      var active = $(this);
      $("table.data tr.data").show();
      $("select.filter").attr('disabled', false);
      var val = $(this).val();
      if (val == "ALLVALS") {
        return;
      }
      $("select.filter").attr('disabled', true);
      $(this).attr('disabled', false);
      $("table.data tr.data").each(function() {
        if ($(this).find("td."+v).text() != val) {
          $(this).hide();
        }
      });
    });
  });

  $("button.filter").on("click", function() {
    $("table.data tr.data").show();
    $("tr.filters").remove();
    sorttable.makeSortable($("table.sortable")[0]);
  });
});