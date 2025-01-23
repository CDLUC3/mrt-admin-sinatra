# frozen_string_literal: true

require 'aws-sdk-lambda'
require_relative '../uc3_client'

# Scope custom code for UC3 to distinguish from 3rd party classes
module UC3Resources
  # Query for repository images by tag
  class FunctionsClient < UC3::UC3Client
    def initialize
      @client = Aws::Lambda::Client.new(
        region: UC3::UC3Client.region
      )
      @functions = {}
      @client.list_functions.functions.each do |function|
        @functions[function.function_name] = {
          name: function.function_name,
          runtime: function.runtime,
          timeout: function.timeout,
          memory: function.memory_size,
          last_modified: function.last_modified,
          package_type: function.package_type,
          arn: function.function_arn
        }
      end
      super(enabled: enabled)
    rescue StandardError => e
      super(enabled: false, message: e.to_s)
    end

    def enabled
      !@client.nil?
    end

    def list_functions(filters: {})
      table = AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:name, header: 'Name'),
          AdminUI::Column.new(:runtime, header: 'Runtime', filterable: true),
          AdminUI::Column.new(:timeout, header: 'Timeout'),
          AdminUI::Column.new(:memory, header: 'Memory'),
          AdminUI::Column.new(:last_modified, header: 'Last Modified'),
          AdminUI::Column.new(:package_type, header: 'Package Type'),
          AdminUI::Column.new(:program, header: 'Program', filterable: true),
          AdminUI::Column.new(:service, header: 'Service', filterable: true)
        ]
      )
      return table unless enabled

      @functions.sort.each do |key, value|
        tags = @client.list_tags(resource: value[:arn]).tags.to_h
        value[:program] = tags.fetch('Program', '')
        value[:service] = tags.fetch('Service', '')
        table.add_row(AdminUI::Row.make_row(table.columns, value))
      end
      table
    end
  end
end
