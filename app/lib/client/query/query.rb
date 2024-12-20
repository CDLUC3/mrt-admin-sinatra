# frozen_string_literal: true

require 'mysql2'
require 'yaml'
require_relative '../uc3_client'

# Scope custom code for UC3 to distinguish from 3rd party classes
module UC3Query
  # Query for repository images by tag
  class QueryClient < UC3::UC3Client
    def self.client
      UC3::UC3Client.clients.fetch(self.class.to_s, QueryClient.new)
    end

    def initialize
      @queries = load_config('app/config/query.sql.yml').fetch(:queries, [])
      map = lookup_map('app/config/query.lookup.yml')
      config = resolve_lookup('app/config/query.template.yml', map)
      dbconf = config.fetch('dbconf', {})
      @client = Mysql2::Client.new(dbconf)
      super(enabled: enabled)
    rescue StandardError => e
      super(enabled: false, message: e.to_s)
    end

    def enabled
      !@client.nil?
    end

    def create_menu_items
      AdminUI::Context.add_menu_item(AdminUI::MENU_QUERY, 'Queries')
      @queries.each do |query|
        path = query.fetch(:route, '')
        name = query.fetch(:name, '')
        query.fetch(:menuitems, []).each do |menuitem|
          mp = menuitem.fetch(:menupath, '')
          next if mp.empty?

          AdminUI::Context.add_menu_item(mp, menuitem.fetch(:name, name), menuitem.fetch(:path, path))
        end
      end
    end

    def query(path)
      table = AdminUI::FilterTable.empty(path)
      query = @queries.find { |q| q.fetch(:route, '') == path }
      return table if query.nil?

      sql = query.fetch(:sql, '')
      return table if sql.empty?

      stmt = @client.prepare(sql)
      cols = stmt.fields.map do |field|
        AdminUI::Column.new(field, header: field)
      end
      table = AdminUI::FilterTable.new(
        columns: cols
      )
      stmt.execute.each do |row|
        table.add_row(AdminUI::Row.make_row(table.columns, row))
      end
      table
    end

    attr_accessor :queries
  end
end
