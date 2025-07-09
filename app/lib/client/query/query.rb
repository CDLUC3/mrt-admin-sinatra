# frozen_string_literal: true

require 'anbt-sql-formatter/formatter'
require 'mysql2'
require 'yaml'
require_relative '../uc3_client'
require_relative '../../ui/context'

# Scope custom code for UC3 to distinguish from 3rd party classes
module UC3Query
  # Query for repository images by tag
  class QueryClient < UC3::UC3Client
    def self.client
      UC3::UC3Client.clients.fetch(self.class.to_s, QueryClient.new)
    end

    def initialize
      @columndefs = {}
      @fragments = {}
      @queries = {}

      Dir.glob('app/config/mrt/query/query.sql.*.yml').each do |file|
        config = UC3::UC3Client.load_config(file)
        @columndefs.merge!(config.fetch(:columns, {}))
        @fragments.merge!(config.fetch(:fragments, {}))
        @queries.merge!(config.fetch(:queries, {}))
      rescue StandardError => e
        puts "#{e.class}: #{e} in #{file}"
      end

      key = ENV.fetch('configkey', 'default')
      tmap = YAML.safe_load_file('app/config/mrt/query.lookup.yml', aliases: true)
      tmap = tmap.fetch(key, {})
      map = UC3::UC3Client.lookup_map(tmap)
      config = UC3::UC3Client.resolve_lookup('app/config/mrt/query.template.yml', map)
      @dbconf = config.fetch('dbconf', {})
      @dbconf[:connect_timeout] = 10
      @dbconf[:read_timeout] = 120
      @client = Mysql2::Client.new(@dbconf)
      @formatter = AnbtSql::Formatter.new(AnbtSql::Rule.new)
      super(enabled: enabled)
    rescue StandardError => e
      puts "#{e.class}: #{e}; #{e.backtrace.join("\n")}"
      super(enabled: false, message: e.to_s)
    end

    def enabled
      !@client.nil?
    end

    def resolve_parameters(qparams, urlparams)
      vals = []
      qparams.each do |param|
        if param.key?(:name) && param[:type] == 'date'
          dv = Date.today.strftime('%Y-%m-%d')
          begin
            dv = Date.parse(urlparams.fetch(param[:name], dv)).strftime('%Y-%m-%d')
          rescue StandardError
            # use dv
          end
          vals << dv
        elsif param.key?(:name) && param[:type] == 'integer'
          vals << urlparams.fetch(param[:name], '-1').to_i
        elsif param.key?(:name)
          vals << urlparams.fetch(param[:name], '')
        end
      end
      vals
    end

    def run_sql(sql, args = [])
      hasharr = []
      begin
        stmt = @client.prepare(Mustache.render(sql, @fragments))
        stmt.execute(*args).each do |row|
          hasharr << row.to_h
        end
      rescue StandardError => e
        puts "#{e.class}: #{e}"
      end
      hasharr
    end

    def make_column(field)
      coldef = @columndefs.fetch(:names, {}).fetch(field.to_sym, {})
      if coldef.empty?
        @columndefs.fetch(:patterns, {}).each do |pattern, cd|
          coldef = cd if field =~ Regexp.new(pattern.to_s)
        end
      end
      header = coldef.fetch(
        :header,
        field.gsub('_', ' ').split.map(&:capitalize).join(' ').gsub('Gb', 'GB')
      )
      cssclass = coldef.fetch(:cssclass, '')
      AdminUI::Column.new(
        field,
        header: header,
        filterable: coldef.fetch(:filterable, false),
        id: coldef.fetch(:id, false),
        idlist: coldef.fetch(:idlist, false),
        link: coldef.fetch(:link, false),
        prefix: coldef.fetch(:prefix, ''),
        cssclass: "#{field} #{cssclass}"
      )
    end

    def result_header(path, sql)
      sep = path.index('?') ? '&' : '?'
      <<~HTML
        <details>
          <summary>SQL</summary>
          <div>
            <a href='#{path}#{sep}format=json'>JSON</a>
            <a href='#{path}#{sep}format=csv'>CSV</a>
            <a href='#{path}#{sep}format=text'>TEXT</a>
          </div>
          <pre>#{@formatter.format(sql).gsub(' (', '(')}</pre>
        </details>
      HTML
    end

    def query(path, urlparams, sqlsym: :sql)
      table = AdminUI::FilterTable.empty
      query = @queries.fetch(path.to_sym, {})
      return nil if query.empty?

      sql = query.fetch(sqlsym, '')
      return table if sql.empty?

      # get know query parameters from yaml
      tparm = query.fetch(:'template-params', {})
      # populate additional parameters using a query
      query.fetch(:'template-sql', {}).each do |key, value|
        tparm[key] = run_sql(value)
      end
      # resolve re-usable fragments found in template parameters
      tparm.each do |key, value|
        tparm[key] = Mustache.render(value, @fragments) if value.is_a?(String)
      end
      # inject parameters into the sql.  allow 2 levels of nesting
      sql = Mustache.render(sql, @fragments.merge(tparm))
      sql = Mustache.render(sql, @fragments.merge(tparm))

      return AdminUI::FilterTable.empty(sql) unless enabled

      begin
        stmt = @client.prepare(sql)
        cols = stmt.fields.map do |field|
          make_column(field)
        end

        description = Mustache.render(query.fetch(:description, ''), tparm)
        description += result_header(path, sql)
        table = AdminUI::FilterTable.new(
          columns: cols,
          totals: query.fetch(:totals, false),
          description: description
        )

        params = resolve_parameters(query.fetch(:parameters, []), urlparams)
        stmt.execute(*params).each do |row|
          table.add_row(AdminUI::Row.make_row(table.columns, row))
        end
        msg = { path: path, status: table.status }
        puts msg.to_json
        record_status(path, table.status) if query.fetch(:status_check, false)
      rescue StandardError => e
        arr = [
          "#{e.class}: #{e}",
          result_header(path, sql),
          params.to_s,
          "Connect timeout: #{@dbconf[:connect_timeout]}",
          "Read timeout: #{@dbconf[:read_timeout]}"
        ]
        table = AdminUI::FilterTable.empty(arr.join('<hr/>'), status: :ERROR, status_message: e.to_s)
      end
      table
    end

    attr_accessor :queries

    def update_billing
      stmt = @client.prepare('call update_object_size()')
      stmt.execute
      stmt = @client.prepare('call update_node_counts()')
      stmt.execute
      stmt = @client.prepare('call update_billing_range()')
      stmt.execute
      stmt = @client.prepare('call clear_range(date(now()), date_add(date(now()), interval 1 day))')
      stmt.execute
      stmt = @client.prepare('call pull_range(date(now()), date_add(date(now()), interval 1 day))')
      stmt.execute
      stmt = @client.prepare('call update_audits_processed()')
      stmt.execute
      stmt = @client.prepare('call update_ingests_processed()')
      stmt.execute
    end
  end
end
