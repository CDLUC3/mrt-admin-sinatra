# frozen_string_literal: true

# admin ui components
module AdminUI
  # Table rendering classes
  class FilterTable
    def self.empty(message = '')
      return FilterTable.new if message.empty?

      FilterTable.new(
        columns: [
          Column.new('message')
        ],
        data: [
          Row.new([message])
        ]
      )
    end

    def initialize(columns: [], data: [], filters: [], totals: false, description: '')
      @columns = columns
      @rows = data
      @filters = filters
      @filterable = false
      @totals = totals
      @description = description
      @columns.each do |col|
        @filterable = true if col.filterable
      end
    end

    def add_filter(filter)
      @filters.push(filter)
    end

    def add_row(row)
      @rows.push(row)
    end

    def add_column(column)
      @columns.push(column)
      @filterable = true if column.filterable
    end

    def render_column_headers
      s = ''
      @columns.each do |col|
        s += "<th class='#{col.cssclass}'>#{col.header}</th>"
      end
      s
    end

    def render_column_filters
      s = ''
      if filterable
        s += %(<tr class='filters'>)
        @columns.each_with_index do |col, i|
          s += %(<th class='#{col.cssclass}'>)
          s += %(<button class='filter' title='remove filters to make table sortable'>Clear</button>) if i.zero?
          if col.filterable
            s += %(
            <select data='#{col.cssclass}' class='filter'>
              <option value='ALLVALS'>All</option>
            </select>
            )
          end
          s += %(</th>)
        end
        s += '</tr>'
      end
      s
    end

    def render
      s = %(
    <table class='data sortable'>
    <caption>
      #{render_description}
      #{render_filters}
    </caption>
    <thead>
    <tr class='header'>
      #{render_column_headers}
    </tr>
    #{render_column_filters}
    </thead>
    <tbody>
    )
      @rows.each do |row|
        s += row.render(@columns)
      end
      s += %(</tbody>)
      if @totals
        s += %(<tfoot><tr class='totals'>)
        @columns.each_with_index do |col, i|
          s += %(<td class='#{col.cssclass}'>)
          s += i.zero? ? 'Total' : ''
          s += %(</td>)
        end
        s += %(</tr></tfoot>)
      end
      s += %(</table>)
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

    def render_description
      return '' if @description.empty?

      %(<div class='description'>#{Redcarpet::Markdown.new(Redcarpet::Render::HTML.new).render(@description)}</div>)
    end

    attr_accessor :columns, :data, :filters, :filterable, :totals
  end

  # Table rendering classes
  class Row
    def initialize(data, cssclass: '')
      @cssclass = cssclass
      @cols = data
    end

    def self.format_float(vfloat)
      i = vfloat.to_i
      d = vfloat - i
      "#{format_int(i)}.#{format('%.2f', d)[2..3]}"
    end

    def self.format_int(vint)
      vint.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    end

    def self.make_row(cols, datahash)
      cssclass = datahash.fetch(:cssclass, 'data')
      data = []
      cols.each do |col|
        v = datahash.fetch(col.sym, col.defval)
        v = '' if v.nil?
        if v.is_a?(BigDecimal)
          v = col.cssclass.split.include?('float') ? format_float(v.to_f) : format_int(v.to_i)
        end
        if col.id
          pre = col.prefix
          v = { value: v, href: "#{pre}#{v}" } unless pre.empty?
        elsif col.idlist
          pre = col.prefix
          arr = v.split(',').map do |vv|
            (pre.empty? ? vv : { value: vv, href: "#{pre}#{vv}", title: vv })
          end
          v = arr
        elsif v.is_a?(Integer)
          v = format_int(v)
        elsif v.is_a?(Float)
          v = format_float(v)
        end
        data << v
      end
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
    def initialize(sym, cssclass: '', header: '', spanclass: 'val', defval: '', filterable: false, id: false,
      idlist: false, prefix: '')
      @sym = sym
      @cssclass = cssclass.empty? ? sym.to_s : cssclass
      @header = header.empty? ? sym.to_s : header
      @spanclass = spanclass
      @defval = defval
      @filterable = filterable
      @id = id
      @idlist = idlist
      @prefix = prefix
    end

    attr_accessor :sym, :cssclass, :header, :spanclass, :defval, :filterable, :id, :idlist, :prefix

    def render(cellval)
      if cellval.is_a?(Array)
        s = ''
        cellval.each do |vv|
          s += "<span class='#{spanclass}' title='#{vv}'>#{render(vv)}</span>"
        end
        s.to_s
      elsif cellval.is_a?(Hash)
        val = cellval.fetch(:value, '')
        if val.to_s.empty?
          render_string('')
        elsif cellval.key?(:href)
          href = cellval.fetch(:href, '')
          title = cellval.fetch(:title, '')
          render_link(val, href, cssclass: cellval.fetch(:cssclass, ''), title: title)
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

    def render_link(val, href, cssclass: '', title: '')
      "<a href='#{href}' class='#{cssclass}' title='#{title}'>#{val}</a>"
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
