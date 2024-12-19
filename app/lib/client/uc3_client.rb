# frozen_string_literal: true
require 'aws-sdk-ssm'
require 'mustache'
require 'yaml'
require_relative '../ui/table'

# Scope custom code for UC3 to distinguish from 3rd party classes
module UC3
  # Base class for UC3 client classes
  class UC3Client
    @@clients = {}
    def initialize(penabled = true, message: '') 
      @@clients[self.class.to_s] = {name: self.class.to_s, enabled: penabled, message: message}      
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
          AdminUI::Column.new(:name, header: 'Client'),
          AdminUI::Column.new(:enabled, header: 'Enabled'),
          AdminUI::Column.new(:message, header: 'Message')
        ]
      )
      @@clients.sort.each do |key, value|
        table.add_row(AdminUI::Row.make_row(table.columns, value))
      end
      table
    end

    def lookup_map(filename)
      ssm = Aws::SSM::Client.new(
        region: UC3::UC3Client::region
      )
      map = YAML.safe_load(File.read(filename))
      map.each do |key, value|
        if value.key?('ssm')
          resp = ssm.get_parameter(name: value['ssm'], with_decryption: true)
          map[key] = resp.parameter.value
        elsif value.key?('env')
          map[key] = ENV.fetch(value['env'], value.fetch('default', ''))
        end

        case value.fetch('type', 'string')
        when 'int'
          map[key] = map[key].to_i
        when 'float'
          map[key] = map[key].to_f
        end
      end
      map
    end

    def resolve_lookup(filename, map)
      YAML.safe_load(Mustache.render(File.read(filename), map))
    end
  end
end
