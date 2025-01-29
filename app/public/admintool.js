$(document).ready(function() {
  showTotals();
  applySearchBox();
  applyButtonDisabled();
  applyFilterCheckboxes();
  applyFilters();
  clearButton();
});

function applySearchBox() {
  var type = localStorage.getItem('search_type');
  type = type ? type : '';
  $("select[name='search_type']").find("option[value='"+type+"']").attr('selected', true);
  $("select[name='search_type']").on("change", function() {
    localStorage.setItem('search_type', $(this).val());
  });
}

function applyButtonDisabled() {
  // Allow links to be disabled in table displays
  $("table.data a").on("click", function() {
    if ($(this).hasClass('button-disabled')) {
      return false;
    }
  });
}

function applyFilterCheckboxes() {
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
    showTotals();
  });
}

function applyFilters() {
  $("select.filter").each(function() {
    var sel = $(this);
    var v = $(this).attr('data');
    vals = {}
    $("td."+v+",th."+v).each(function() {
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
        if ($(this).find("td."+v+",th."+v).text() != val) {
          $(this).hide();
        }
      });
      showTotals();
    });
  });
}

function clearButton() {
  $("button.filter").on("click", function() {
    $("table.data tr.data").show();
    $("tr.filters").remove();
    sorttable.makeSortable($("table.sortable")[0]);
  });
}

function showTotals() {
  var test = [
    'int', 
    'float', 
    'files', 
    'size',
    'size_gb',
    'count',
    'num_colls',
    'num_objs',
    'num_objs_2day',
    'num_objs_1day',
    'num_objs_0day'
  ];
  $("tfoot tr.totals").find("th").each(function() {
    var b = false;
    for (var i = 0; i < test.length; i++) {
      if ($(this).hasClass(test[i])) {
        b = true;
        break;
      }
    }
    if (b) {
      var total = 0;
      var c = $(this).attr('class').split(' ')[0];
      var isfloat = $(this).hasClass('float');
      $("td." + c + ":visible").each(function() {
        var v = $(this).text();
        if (v == '' || v == null) return;
        v = v.replace(/,/g, '');
        total += isfloat ? parseFloat(v) : parseInt(v);
      });
      $(this).text(total.toLocaleString());
    }
  });
}