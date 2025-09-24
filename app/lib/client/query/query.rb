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

    def query(path, urlparams, sqlsym: :sql, dispcols: [], resolver: UC3Query::QueryClient.method(:default_resolver))
      table = AdminUI::FilterTable.empty
      query = @queries.fetch(path.to_sym, {})

      sql = query.fetch(sqlsym, '')
      return table if sql.empty?

      # get know query parameters from yaml
      tparm = query.fetch(:'template-params', {})
      pagination = { enabled: false }

      if query.fetch(:limit, {}).fetch(:enabled, false)
        tparm[:LIMIT] = query.fetch(:limit, {}).fetch(:default, urlparams.fetch('limit', '25').to_i)
        tparm[:OFFSET] = urlparams.fetch('offset', '0').to_i
        pagination[:path] = path
        pagination[:urlparams] = urlparams
        pagination[:enabled] = true
        pagination[:LIMIT] = tparm[:LIMIT]
        pagination[:OFFSET] = tparm[:OFFSET]
        pagination[:WINDOW] = tparm[:LIMIT] + tparm[:OFFSET]
      end

      # populate additional parameters using a query
      query.fetch(:'template-sql', {}).each do |key, value|
        tparm[key] = run_sql(value)
      end
      # resolve re-usable fragments found in template parameters
      tparm.each do |key, value|
        tparm[key] = Mustache.render(value, @fragments.merge(pagination)) if value.is_a?(String)
      end
      # inject parameters into the sql.  allow 3 levels of nesting
      sql = Mustache.render(sql, @fragments.merge(tparm))
      sql = Mustache.render(sql, @fragments.merge(tparm))
      sql = Mustache.render(sql, @fragments.merge(tparm))

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
        description += result_header(path, sql)
        table = AdminUI::FilterTable.new(
          columns: cols,
          totals: query.fetch(:totals, false),
          status: query.fetch(:status, :SKIP),
          description: description,
          pagination: pagination
        )

        params = resolve_parameters(query.fetch(:parameters, []), urlparams)
        stmt.execute(*params).each do |row|
          row = resolver.call(row)
          table.add_row(AdminUI::Row.make_row(table.columns, row))
        end
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
      record_status(path, table.status) if query.fetch(:status_check, false)
      table
    end

    def self.default_resolver(row)
      row
    end

    def self.obj_info_resolver(row)
      row['metadata'] = []
      row['metadata'] << "What: #{row['erc_what']}"
      row['metadata'] << "Who: #{row['erc_who']}"
      row['metadata'] << "When: #{row['erc_when']}"
      row['metadata'] << "Own: #{row['name']}"

      row['actions'] = []
      row['actions'] << {
        value: 'Trigger Replication',
        href: "/ops/replication/#{row['inv_object_id']}",
        cssclass: 'button',
        post: true,
        disabled: storage_mgt_disabled?
      }
      row
    end

    def self.obj_node_resolver(row)
      row['actions'] = []
      row['actions'] << {
        value: 'Re-audit All Files',
        href: "/tbd/#{row['inv_object_id']}",
        cssclass: 'button',
        post: true,
        disabled: storage_mgt_disabled?
      }
      row['actions'] << {
        value: 'Re-audit Unverified',
        href: "/tbd/#{row['inv_object_id']}",
        cssclass: 'button',
        post: true,
        disabled: storage_mgt_disabled?
      }
      if row['role'] == 'primary'
        row['actions'] << {
          value: 'Get Manifest',
          href: "/tbd/#{row['inv_object_id']}",
          cssclass: 'button',
          post: true,
          disabled: storage_mgt_disabled?
        }
        row['actions'] << {
          value: "Get Ingest Checkm (v#{row['version_number']})",
          href: "/tbd/#{row['inv_object_id']}",
          cssclass: 'button',
          post: true,
          disabled: storage_mgt_disabled?
        }
        row['actions'] << {
          value: 'Get Storage Manifest Yaml',
          href: "/tbd/#{row['inv_object_id']}",
          cssclass: 'button',
          post: true,
          disabled: storage_mgt_disabled?
        }
        row['actions'] << {
          value: 'Get Storage Provenance Yaml',
          href: "/tbd/#{row['inv_object_id']}",
          cssclass: 'button',
          post: true,
          disabled: storage_mgt_disabled?
        }
        row['actions'] << {
          value: 'Get Storage Provenance Diff',
          href: "/tbd/#{row['inv_object_id']}",
          cssclass: 'button',
          post: true,
          disabled: storage_mgt_disabled?
        }
        row['actions'] << {
          value: 'Rebuild Inventory',
          href: "/tbd/#{row['inv_object_id']}",
          cssclass: 'button button_red',
          confmsg: %(Are you sure you want to rebuild the INV entry for this ark?
            A new inv_object_id will be assigned.),
          post: true,
          disabled: storage_mgt_disabled?
        }
        row['actions'] << {
          value: 'Clear Scan Entries for Ark',
          href: "/tbd/#{row['inv_object_id']}",
          cssclass: 'button',
          post: true,
          disabled: storage_mgt_disabled?
        }
      end
      row
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
        objid = row['inv_object_id']
        run_sql(
          %(
            update
              inv_audits
            set
              verified = null,
              status = 'unknown'
            where
              inv_object_id = ?
            and
              inv_node_id = ?
          ),
          [objid, 16]
        )
      end
      table
    end
  end
end
