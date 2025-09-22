$(document).ready(function() {
  showTotals();
  applySearchBox();
  applyButtonControls();
  applyFilterCheckboxes();
  applyFilters();
  applyMenuPost();
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

function applyButtonControls() {
  // Allow links to be disabled in table displays
  $("table.data a").on("click", function() {
    if ($(this).attr('disabled')) {
      return false;
    }
    if ($(this).hasClass('post')) {
      $(this).attr('disabled', true);
      self = this;

      var confmsg = $(this).attr('confmsg') || '';
      if (confmsg != '') {
        confmsg += "\n\nAre you sure you want to proceed?";
        if (!confirm(confmsg)) {
          $(this).attr('disabled', false);
          return false;
        }
      } 

      $.ajax({
        dataType: "json",
        method: "POST",
        contentType: "text/plain; charset=utf-8",
        url: $(this).attr('url'),
        data: $(this).attr('data'),
        success: function(data) {
          if (data['message']) {
            if (data['modal']) {
              confirm(data['message']);
            } else {
              $("#alertmsg").text(data['message']).dialog({
                create: function(event, ui) {
                  $(event.target).parent().css('position', 'fixed');
                },
                show: { effect: "blind", duration: 800 },
                position: { my: "right", at: "left", of: self }
              });
            }
            if (data['redirect']) {
              document.location = data['redirect'];
            }
          }
        },
        error: function( xhr, status ) {
          $("#alertmsg").text(xhr.responseText).dialog({
            create: function(event, ui) {
              $(event.target).parent().css('position', 'fixed');
            },
            show: { effect: "blind", duration: 800 },
            position: { my: "right", at: "left", of: self }
          });
        }
      });
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
        showTotals();
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
    'cost',
    'size_gb',
    'count',
    'num_colls',
    'num_objs',
    'num_objs_2day',
    'num_objs_1day',
    'num_objs_0day',
    'start_size_gb',
    'end_size_gb',
    'diff_size_gb',
    'ytd_size_gb',
    'average_available_gb',
    'daily_average_projected_gb'
  ];
  $("tfoot tr.totals").find("td").each(function() {
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
      $("tbody td." + c + ":visible").each(function() {
        var v = $(this).text();
        if (v == '' || v == null) return;
        v = v.replace(/,/g, '');
        total += isfloat ? parseFloat(v) : parseInt(v);
      });
      $(this).text(total.toLocaleString());
    }
  });
}

function applyMenuPost() {
  $("a.post-link").on("click", function() {
    var confmsg = $(this).attr('confmsg') || '';
    confmsg += "\n\nAre you sure you want to proceed?";

    if (confirm(confmsg)) {
      const route = $(this).attr('data-route');
      const form = $('<form></form>').attr('method', 'POST').attr('action', route).text($(this).attr('data'));
      form.appendTo('body');
      form.submit();  
    }
    return false;
  });
}
