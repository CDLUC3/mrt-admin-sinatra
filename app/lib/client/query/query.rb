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
      @queries = UC3::UC3Client.load_config('app/config/mrt/query.sql.yml').fetch(:queries, [])
      @fragments = UC3::UC3Client.load_config('app/config/mrt/query.sql.yml').fetch(:fragments, [])
      map = UC3::UC3Client.lookup_map('app/config/mrt/query.lookup.yml')
      config = UC3::UC3Client.resolve_lookup('app/config/mrt/query.template.yml', map)
      @dbconf = config.fetch('dbconf', {})
      @dbconf[:connect_timeout] = 10
      @dbconf[:read_timeout] = 120
      @client = Mysql2::Client.new(@dbconf)
      @formatter = AnbtSql::Formatter.new(AnbtSql::Rule.new)
      super(enabled: enabled)
    rescue StandardError => e
      super(enabled: false, message: e.to_s)
    end

    def enabled
      !@client.nil?
    end

    def resolve_parameters(qparams, urlparams)
      vals = []
      qparams.each do |param|
        if param.key?(:value)
          vals << param[:value]
        elsif param.key?(:name) && param[:type] == 'integer'
          vals << urlparams.fetch(param[:name], '-1').to_i
        elsif param.key?(:name)
          vals << urlparams.fetch(param[:name], '')
        end
      end
      vals
    end

    def run_sql(sql)
      hasharr = []
      begin
        stmt = @client.prepare(Mustache.render(sql, @fragments))
        stmt.execute.each do |row|
          hasharr << row.to_h
        end
      rescue StandardError => e
        puts "#{e.class}: #{e}"
      end
      hasharr
    end

    def query(path, urlparams, sqlsym: :sql)
      table = AdminUI::FilterTable.empty
      query = @queries.fetch(path.to_sym, {})
      return table if query.nil?

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
          filterable = AdminUI::FilterTable.filterable_fields.include?(field)
          col = AdminUI::Column.new(field, header: field, filterable: filterable)
          col.cssclass += ' float' if field =~ /^(cost|size|.*_gb)$/
          col.cssclass += ' float' if field =~ /^\d\d\d\d-\d\d-\d\d$/
          col
        end

        description = Mustache.render(query.fetch(:description, ''), tparm)
        description += "<details><summary>SQL</summary><pre>#{@formatter.format(sql)}</pre></details>"
        table = AdminUI::FilterTable.new(
          columns: cols,
          totals: query.fetch(:totals, false),
          description: description
        )
        params = resolve_parameters(query.fetch(:parameters, []), urlparams)
        stmt.execute(*params).each do |row|
          table.add_row(AdminUI::Row.make_row(table.columns, row))
        end
      rescue StandardError => e
        arr = [
          "#{e.class}: #{e}",
          "<details><summary>SQL</summary><pre>#{@formatter.format(sql)}</pre></details>",
          params.to_s,
          "Connect timeout: #{@dbconf[:connect_timeout]}",
          "Read timeout: #{@dbconf[:read_timeout]}"
        ]
        return AdminUI::FilterTable.empty(arr.join('<hr/>'))
      end
      table
    end

    attr_accessor :queries
  end
end
