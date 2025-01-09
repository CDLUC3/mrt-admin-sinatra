# frozen_string_literal: true

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
      map = UC3::UC3Client.lookup_map('app/config/mrt/query.lookup.yml')
      config = UC3::UC3Client.resolve_lookup('app/config/mrt/query.template.yml', map)
      dbconf = config.fetch('dbconf', {})
      @client = Mysql2::Client.new(dbconf)
      super(enabled: enabled)
    rescue StandardError => e
      super(enabled: false, message: e.to_s)
    end

    def enabled
      !@client.nil?
    end

    def query(path)
      table = AdminUI::FilterTable.empty(path)
      query = @queries.fetch(path.to_sym, {})
      return table if query.nil?

      sql = query.fetch(:sql, '')
      return table if sql.empty?

      tparm = query.fetch(:'template-params', {})
      puts tparm
      sql = Mustache.render(sql, tparm) unless tparm.empty?

      return AdminUI::FilterTable.empty("No DB support for: #{sql}") unless enabled

      stmt = @client.prepare(sql)
      cols = stmt.fields.map do |field|
        filterable = %w[ogroup mime_group mime_type mnemonic_filter].include?(field)
        AdminUI::Column.new(field, header: field, filterable: filterable)
      end
      table = AdminUI::FilterTable.new(
        columns: cols,
        totals: query.fetch(:totals, false)
      )
      stmt.execute.each do |row|
        table.add_row(AdminUI::Row.make_row(table.columns, row))
      end
      table
    end

    attr_accessor :queries
  end
end
