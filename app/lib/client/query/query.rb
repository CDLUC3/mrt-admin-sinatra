# frozen_string_literal: true

require 'anbt-sql-formatter/formatter'
require 'mysql2'
require 'yaml'
require_relative '../uc3_client'
require_relative '../../ui/context'
require_relative 'query_resolvers'

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
        puts "(Query1) #{e.class}: #{e} in #{file}"
      end

      map = UC3::UC3Client.lookup_map_by_filename(
        'app/config/mrt/query.lookup.yml',
        key: ENV.fetch('configkey', 'default')
      )
      config = UC3::UC3Client.resolve_lookup('app/config/mrt/query.template.yml', map)
      @dbconf = config.fetch('dbconf', {})
      @dbconf[:connect_timeout] = 10
      @client = Mysql2::Client.new(@dbconf)
      @formatter = AnbtSql::Formatter.new(AnbtSql::Rule.new)
      super(enabled: enabled)
    rescue StandardError => e
      puts "(Query2) #{e.class}: #{e};"
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
        rows = stmt.execute(*args)
        rows = [] if rows.nil?
        rows.each do |row|
          hasharr << row.to_h
        end
      rescue StandardError => e
        puts "(Query3) #{e.class}: #{e}"
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

    def self.make_url_with_key(path, params, key, value)
      p = params.clone
      uri = URI(path)
      p[key] = value
      uri.query = URI.encode_www_form(p)
      uri.to_s
    end

    def result_header(path, params, sql)
      <<~HTML
        <details>
          <summary>SQL</summary>
          <div>
            <a href="#{UC3Query::QueryClient.make_url_with_key(path, params, 'admintoolformat', 'json')}">JSON</a>
            <a href="#{UC3Query::QueryClient.make_url_with_key(path, params, 'admintoolformat', 'csv')}">CSV</a>
            <a href="#{UC3Query::QueryClient.make_url_with_key(path, params, 'admintoolformat', 'text')}">TEXT</a>
          </div>
          <pre>#{@formatter.format(sql).gsub(' (', '(')}</pre>
        </details>
      HTML
    end

    def limit(query, urlparams)
      query.fetch(:limit, {}).fetch(:default, urlparams.fetch('limit', '25').to_i)
    end

    def offset(urlparams)
      urlparams.fetch('offset', '0').to_i
    end

    def pagination_params(query, path, urlparams)
      pag = { enabled: false }
      if query.fetch(:limit, {}).fetch(:enabled, false)
        pag[:path] = path
        pag[:urlparams] = urlparams
        pag[:enabled] = true
        pag[:LIMIT] = limit(query, urlparams)
        pag[:OFFSET] = offset(urlparams)
        pag[:WINDOW] = limit(query, urlparams) + offset(urlparams)
      end
      pag
    end

    def template_params(query, urlparams, pagination)
      tparm = query.fetch(:'template-params', {})
      if query.fetch(:limit, {}).fetch(:enabled, false)
        tparm[:LIMIT] = limit(query, urlparams)
        tparm[:OFFSET] = offset(urlparams)
      end

      # populate additional parameters using a query
      query.fetch(:'template-sql', {}).each do |key, value|
        tparm[key] = run_sql(value)
      end

      # resolve re-usable fragments found in template parameters
      tparm.each do |key, value|
        tparm[key] = Mustache.render(value, @fragments.merge(pagination)) if value.is_a?(String)
      end
      tparm
    end

    def resolve_sql(sql, tparm)
      # inject parameters into the sql.  allow 3 levels of nesting
      sql = Mustache.render(sql, @fragments.merge(tparm))
      sql = Mustache.render(sql, @fragments.merge(tparm))
      Mustache.render(sql, @fragments.merge(tparm))
    end

    def query_update(path, urlparams = {}, sqlsym: :sql, purpose: '')
      query = @queries.fetch(path.to_sym, {})

      sql = query.fetch(sqlsym, '')
      return { message: 'SQL is empty' } if sql.empty?
      return { message: 'Not an update query' } unless query.fetch(:update, false)

      begin
        stmt = @client.prepare(sql)

        params = resolve_parameters(query.fetch(:parameters, []), urlparams)

        stmt.execute(*params)
      rescue StandardError => e
        return {
          status: 'FAIL',
          message: "#{purpose} SQL: #{e.class}: #{e}"
        }
      end
      { status: 'OK', message: "#{purpose} Update completed. #{stmt.affected_rows} rows" }
    end

    def run_query(path, urlparams = {}, sqlsym: :sql)
      query = @queries.fetch(path.to_sym, {})

      sql = query.fetch(sqlsym, '')
      return [] if sql.empty?
      return [] if query.fetch(:update, false)

      # get know query parameters from yaml
      pagination = pagination_params(query, path, urlparams)
      tparm = template_params(query, urlparams, pagination)

      # Design idea: allow sql to be an array of sql statements.
      # This would permit us to create temporary tables to use in subsequent queries.

      sql = resolve_sql(sql, tparm)
      return [] unless enabled

      stmt = @client.prepare(sql)

      params = resolve_parameters(query.fetch(:parameters, []), urlparams)

      rs = stmt.execute(*params)
      rs.map(&:to_h)
    end

    def query(path, urlparams, sqlsym: :sql, dispcols: [], resolver: UC3Query::QueryResolvers.method(:default_resolver))
      table = AdminUI::FilterTable.empty
      query = @queries.fetch(path.to_sym, {})

      sql = query.fetch(sqlsym, '')
      return table if sql.empty?
      return table if query.fetch(:update, false)

      # get know query parameters from yaml
      pagination = pagination_params(query, path, urlparams)
      tparm = template_params(query, urlparams, pagination)

      # Design idea: allow sql to be an array of sql statements.
      # This would permit us to create temporary tables to use in subsequent queries.

      sql = resolve_sql(sql, tparm)
      return AdminUI::FilterTable.empty(sql) unless enabled

      begin
        stmt = @client.prepare(sql)
        cols = if dispcols.empty?
                 stmt.fields.map do |field|
                   make_column(field)
                 end
               else
                 dispcols.map do |field|
                   make_column(field)
                 end
               end

        description = Mustache.render(query.fetch(:description, ''), tparm)
        description += result_header(path, urlparams, sql)
        table = AdminUI::FilterTable.new(
          columns: cols,
          totals: query.fetch(:totals, false),
          status: query.fetch(:status, :SKIP),
          description: description,
          pagination: pagination
        )

        params = resolve_parameters(query.fetch(:parameters, []), urlparams)

        s2c = query.fetch(:save_to_cloud, '')
        if s2c.empty?
          stmt.execute(*params).each do |row|
            row = resolver.call(row)
            table.add_row(AdminUI::Row.make_row(table.columns, row))
          end
        else
          rptpath = Mustache.render(s2c, urlparams)
          CSV.generate do |csv|
            crow = cols.map(&:header)
            csv << crow
            stmt.execute(*params).each do |row|
              csv << row.values
            end
            UC3S3::ConfigObjectsClient.client.create_report(rptpath, csv.string)
            return rptpath
          end
        end
      rescue StandardError => e
        arr = [
          "#{e.class}: #{e}",
          result_header(path, urlparams, sql),
          params.to_s,
          "Connect timeout: #{@dbconf[:connect_timeout]}",
          "Read timeout: #{@dbconf[:read_timeout]}"
        ]
        table = AdminUI::FilterTable.empty(arr.join('<hr/>'), status: :ERROR, status_message: e.to_s)
      end
      puts 1111
      record_status(path, table.status) if query.fetch(:status_check, false)
      puts 2222
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

    def reset_new_ucb_content(path, urlparams)
      table = query(path, urlparams)
      table.table_data.each do |row|
        params = {}
        params['inv_object_id'] = row['inv_object_id']
        params['inv_node_id'] = 16
        query_update('/queries-update/audit/reset', params, purpose: 'Reset Audit for New UCB Content')
        # TODO: evaluate return object and present results
      end
      table
    end
  end
end
