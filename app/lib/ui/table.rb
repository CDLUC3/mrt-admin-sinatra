# frozen_string_literal: true

require 'csv'

# admin ui components
module AdminUI
  # Table rendering classes
  class FilterTable
    def self.empty(message = '', status: :SKIP, status_message: '')
      return FilterTable.new if message.empty?

      FilterTable.new(
        columns: [
          Column.new('message')
        ],
        data: [
          Row.new([message])
        ],
        status: status,
        status_message: status_message
      )
    end

    def initialize(columns: [], data: [], filters: [], totals: false, description: '', status: :SKIP,
      status_message: '', pagination: { enabled: false })
      @columns = columns
      @rows = data
      @filters = filters
      @filterable = false
      @totals = totals
      @description = description
      @pagination = pagination
      @columns.each do |col|
        @filterable = true if col.filterable
      end
      @status = status
      @status_message = status_message
    end

    def table_data
      d = []
      @rows.each do |row|
        r = {}
        row.cols.each_with_index do |col, i|
          r[@columns[i].sym.to_sym] = col.is_a?(Hash) ? col.fetch(:value, '') : col
        end
        d.append(r)
      end
      d
    end

    def get_column_index(colsym)
      @columns.each_with_index do |col, i|
        return i if col.sym.to_sym == colsym.to_sym
      end
      -1
    end

    def add_filter(filter)
      @filters.push(filter)
    end

    def add_row(row)
      @rows.push(row)
      i = get_column_index(:status)
      return if i.negative?

      statval = UC3::UC3Client.status_resolve(row.cols[i])
      @status = UC3::UC3Client.status_compare(statval, @status)
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

    def render_status
      %(<div class="#{@status}">#{@status}</div>) if @status
    end

    def render
      s = %(
    <table class='data sortable'>
    <caption>
      #{render_status}
      #{render_counts}
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

    def render_page_link(title, path, urlparams, limit, offset)
      params = urlparams
      params['limit'] = limit
      params['offset'] = offset
      query_string = params.map { |key, value| "#{key}=#{value}" }.join('&')
      %(<a href="#{path}?#{query_string}">#{title}</a>)
    end

    def render_counts
      counts = "#{@rows.length} Row(s)"
      nav = {}
      if pagination.fetch(:enabled, false)
        limit = pagination.fetch(:LIMIT, 0)
        offset = pagination.fetch(:OFFSET, 0)
        path = pagination.fetch(:path, '')
        urlparams = pagination.fetch(:urlprams, {})
        counts += "; Limit: #{limit}; Offset: #{offset}"
        if offset.positive?
          offsetprev = [offset - limit, 0].max
          nav[:prev] = render_page_link('prev', path, urlparams, limit, offsetprev)
          nav[:first] = render_page_link('first', path, urlparams, limit, 0) if offsetprev.positive?
        end
        nav[:next] = render_page_link('next', path, urlparams, limit, offset + limit) if @rows.length == limit
      end
      %(
        <div class='counts'>
        #{nav.fetch(:first, '')}
        #{nav.fetch(:prev, '')}
        <span>#{counts}<span>
        #{nav.fetch(:next, '')}
        </div>
      )
    end

    def render_description
      return '' if @description.empty?

      %(<div class='description'>#{Redcarpet::Markdown.new(Redcarpet::Render::HTML.new,
        fenced_code_blocks: true).render(@description)}</div>)
    end

    def to_csv
      CSV.generate do |csv|
        row = @columns.map(&:header)
        csv << row
        @rows.each do |row|
          data = []
          row.cols.each_with_index do |col, _i|
            if col.is_a?(Hash)
              v = col.fetch(:value, '')
              v = v.to_s if v.is_a?(BigDecimal)
            else
              v = col.to_s
            end
            data << v
          end
          csv << data
        end
      end
    end

    attr_accessor :columns, :data, :filters, :filterable, :totals, :status, :status_message, :description, :pagination
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
        elsif col.link
          v = { value: v, href: v.to_s }
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
      idlist: false, prefix: '', link: false)
      @sym = sym
      @cssclass = cssclass.empty? ? sym.to_s : cssclass
      @header = header.empty? ? sym.to_s : header
      @spanclass = spanclass
      @defval = defval
      @filterable = filterable
      @id = id
      @link = link
      @idlist = idlist
      @prefix = prefix
    end

    attr_accessor :sym, :cssclass, :header, :spanclass, :defval, :filterable, :id, :idlist, :prefix, :link

    def render(cellval)
      if cellval.is_a?(Array)
        s = ''
        cellval.each do |vv|
          title = vv.is_a?(Hash) ? vv.fetch(:title, vv.fetch(:value, '')) : vv
          s += "<span class='#{spanclass}' title='#{title}'>#{render(vv)}</span>"
        end
        s.to_s
      elsif cellval.is_a?(Hash)
        val = cellval.fetch(:value, '')
        if val.to_s.empty?
          render_string('')
        elsif cellval.key?(:href)
          href = cellval.fetch(:href, '')
          title = cellval.fetch(:title, '')
          disabled = cellval.fetch(:disabled, false)
          cssclass = cellval.fetch(:cssclass, '')
          post = cellval.fetch(:post, false)
          data = cellval.fetch(:data, '')
          confmsg = cellval.fetch(:confmsg, '')
          render_link(val, href, cssclass: cssclass, title: title, disabled: disabled, post: post, data: data,
            confmsg: confmsg)
        elsif cellval.key?(:title)
          render_span(val, title: cellval.fetch(:title, ''), cssclass: cellval.fetch(:cssclass, ''))
        else
          cellval.fetch(:value, '').to_s
        end
      elsif @cssclass.split.include?('status')
        render_span(cellval, cssclass: cellval)
      elsif @cssclass.split.include?('check_status')
        # Enable the same CSS logic as a regular status column
        render_span(cellval, cssclass: cellval)
      else
        render_string(cellval.to_s)
      end
    end

    def render_string(val)
      val
    end

    def render_link(val, href, cssclass: '', title: '', disabled: false, post: false, data: '', confmsg: '')
      dis = disabled ? 'disabled' : ''
      if post
        %{
        <a href='javascript:void(0)'
           url='#{href}'
           data='#{data}'
           class='post #{cssclass}'
           title='#{title}'
           confmsg='#{confmsg}'
          #{dis}
        >#{val}</a>
        }
      else
        %(
        <a href='#{href}'
           class='#{cssclass}'
          title='#{title}'
          #{dis}
        >#{val}</a>
        )
      end
    end

    def render_span(val, cssclass: '', title: '')
      "<span class='#{cssclass}' title='#{title}'>#{val}</span>"
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
