class FilterTable
  def initialize(columns: [], data: [], filters: [])
    @columns = columns
    @rows = []
    @filters = filters
  end

  def add_filter(filter)
    @filters.push(filter)
  end

  def add_row(row)
    @rows.push(row)
  end

  def add_column(column)
    @columns.push(column)
  end

  def render
    s = "<table class='data'>"
    s += "<thead>"
    s += "<tr class='header'>"
    @columns.each do |col|
      s += "<th class='#{@classname}'>#{col.header}</th>"
    end
    s += "</tr>"
    s += "</thead>"
    s += "<tbody>"
    @rows.each do |row|
      s += row.render(@columns)
    end
    s += "</tbody>"
    s += "</table>"
    s
  end

  attr_accessor :columns, :data, :filters
end

class Row 
  def initialize(data, cssclass: '')
    @cssclass = cssclass
    @cols = data
  end

  def render(coldefs)
    s = "<tr class='#{@cssclass}'>"
    coldefs.each_with_index do |coldef, i|
      tag = i == 0 ? 'th' : 'td'
      s += "<#{tag} class='#{coldef.cssclass}'>#{coldef.render(@cols[i])}</#{tag}>"
    end
    s += "</tr>"
    s
  end

  attr_accessor :cols, :cssclass

end

class Column 
  def initialize(sym, cssclass: '', header: '')
    @sym = sym
    @cssclass = cssclass
    @header = header.empty? ? sym.to_s : header
  end

  def render(v)
    if (v.is_a?(Array))
      s = ""
      v.each do |vv|
        s += "<span class='val'>#{render(vv)}</span>"
      end
      s.to_s
    elsif v.is_a?(Hash)
      val = v.fetch(:value, '')
      if val.empty?
        render_string("")
      elsif v.has_key?(:href)
        href = v.fetch(:href, '') 
        render_link(val, href, cssclass: v.fetch(:cssclass, ''))
      else
        v.fetch(:value, '').to_s
      end
    else
      render_string(v.to_s)
    end
  end

  def render_string(v)
    v
  end
  
  def render_link(val, href, cssclass: '')
    "<a href='#{href}' class='#{cssclass}'>#{val}</a>"
  end

  attr_accessor :sym, :cssclass, :header

end