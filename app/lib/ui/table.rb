# frozen_string_literal: true

# admin ui components
module AdminUI
  # Table rendering classes
  class FilterTable
    def initialize(columns: [], data: [], filters: [])
      @columns = columns
      @rows = data
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
      s = %(
    <table class='data sortable'>
    <caption>
      #{render_filters}
    </caption>
    <thead>
    <tr class='header'>
    )
      @columns.each do |col|
        s += "<th class='#{col.cssclass}'>#{col.header}</th>"
      end
      s += %(
    </tr>
    </thead>
    <tbody>
    )
      @rows.each do |row|
        s += row.render(@columns)
      end
      s += %(
    </tbody>
    </table>
    )
      s
    end

    def render_filters
      return '' if @filters.empty?
      s = '<div id="controls">'
      @filters.each do |filter|
        s += filter.render
      end
      s += '</div>'
      s
    end

    attr_accessor :columns, :data, :filters
  end

  # Table rendering classes
  class Row
    def initialize(data, cssclass: '')
      @cssclass = cssclass
      @cols = data
    end

    def self.make_row(cols, datahash)
      cssclass = datahash.fetch(:cssclass, 'data')
      data = cols.map { |col| datahash.fetch(col.sym, col.defval) }
      new(data, cssclass: cssclass)
    end

    def render(coldefs)
      s = "<tr class='#{@cssclass}'>"
      coldefs.each_with_index do |coldef, i|
        tag = i.zero? ? 'th' : 'td'
        s += "<#{tag} class='#{coldef.cssclass}'>#{coldef.render(@cols[i])}</#{tag}>"
      end
      s += '</tr>'
      s
    end

    attr_accessor :cols, :cssclass
  end

  # Table rendering classes
  class Column
    def initialize(sym, cssclass: 'data', header: '', spanclass: 'val', defval: '')
      @sym = sym
      @cssclass = cssclass
      @header = header.empty? ? sym.to_s : header
      @spanclass = spanclass
      @defval = defval
    end

    attr_accessor :sym, :cssclass, :header, :spanclass, :defval

    def render(cellval)
      if cellval.is_a?(Array)
        s = ''
        cellval.each do |vv|
          s += "<span class='#{spanclass}'>#{render(vv)}</span>"
        end
        s.to_s
      elsif cellval.is_a?(Hash)
        val = cellval.fetch(:value, '')
        if val.empty?
          render_string('')
        elsif cellval.key?(:href)
          href = cellval.fetch(:href, '')
          render_link(val, href, cssclass: cellval.fetch(:cssclass, ''))
        else
          cellval.fetch(:value, '').to_s
        end
      else
        render_string(cellval.to_s)
      end
    end

    def render_string(val)
      val
    end

    def render_link(val, href, cssclass: '')
      "<a href='#{href}' class='#{cssclass}'>#{val}</a>"
    end
  end

  # Table rendering classes
  class Filter
    def initialize(label, value, match: false)
      @label = label
      @value = value
      @match = match
    end

    def render
      %(
    <span class='filter'>
      <input class='filter' type='checkbox' id='filter-#{@value}' value='#{@value}' match='#{@match}'/>
      <label for='semantic'>#{label}</label>
    </span>
    )
    end

    attr_accessor :label, :value
  end
end
