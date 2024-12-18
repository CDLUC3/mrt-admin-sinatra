# frozen_string_literal: true
require_relative '../ui/table'

# Scope custom code for UC3 to distinguish from 3rd party classes
module UC3
  # Base class for UC3 client classes
  class UC3Client
    @@clients = {}
    def initialize(penabled = true) 
      @@clients[self.class.to_s] = penabled
    end

    def self.region
      ENV['AWS_REGION'] || 'us-west-2'
    end

    def enabled
      false
    end

    def context
      table = AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:key, header: 'Key'),
          AdminUI::Column.new(:value, header: 'Value')
        ]
      )
      ENV.sort.each do |key, value|
         v = key =~ /(KEY|TOKEN|SECRET)/ ? '***' : value
        table.add_row(AdminUI::Row.new([key, v]))
      end
      table
    end

    def clients
      table = AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:client, header: 'Client'),
          AdminUI::Column.new(:enabled, header: 'Enabled')
        ]
      )
      @@clients.sort.each do |key, value|
        table.add_row(AdminUI::Row.new([key, value]))
      end
      table
    end
  end
end
