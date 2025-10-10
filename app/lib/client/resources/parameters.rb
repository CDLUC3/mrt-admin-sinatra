# frozen_string_literal: true

require 'aws-sdk-ssm' unless ENV.fetch('MERRITT_ECS', '').empty?
require_relative '../uc3_client'

# Scope custom code for UC3 to distinguish from 3rd party classes
module UC3Resources
  # Query for repository images by tag
  class ParametersClient < UC3::UC3Client
    def self.client
      UC3::UC3Client.clients.fetch(self.class.to_s, ParametersClient.new)
    end

    def initialize
      @client = Aws::SSM::Client.new(
        region: UC3::UC3Client.region
      )
      @client.get_parameters_by_path(path: '/uc3/foo/bar')
      super(enabled: enabled)
    rescue StandardError => e
      super(enabled: false, message: e.to_s)
    end

    def enabled
      !@client.nil?
    end

    def list_parameters
      table = AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:path, header: 'Path'),
          AdminUI::Column.new(:type, header: 'Type', filterable: true),
          AdminUI::Column.new(:key_id, header: 'Key', filterable: true),
          AdminUI::Column.new(:value, header: 'Value'),
          AdminUI::Column.new(:modified, header: 'Modified'),
          AdminUI::Column.new(:version, header: 'Version')
        ]
      )
      return table unless enabled

      params = {}

      next_token = 'na'
      opt = { path: ENV.fetch('SSM_ROOT_PATH', '/uc3'), recursive: true }
      while next_token
        res = @client.get_parameters_by_path(opt)
        res.parameters.each do |param|
          path = param.name
          value = param.type == 'SecureString' ? '***' : param.value
          value = { value: "#{value[0..100]}...", title: value } if value.length > 100
          params[path] = {
            path: path,
            type: param.type,
            value: value,
            modified: date_format(param.last_modified_date, convert_timezone: true),
            version: param.version
          }
        end
        next_token = res.next_token
        opt[:next_token] = next_token
      end
      next_token = 'na'
      opt = { filters: [{ key: 'Type', values: ['SecureString'] }] }
      while next_token
        res = @client.describe_parameters(opt)
        res.parameters.each do |param|
          path = param.name
          next unless params.key?(path)

          params[path][:key_id] = param.key_id
        end
        next_token = res.next_token
        opt[:next_token] = next_token
      end
      params.sort.each do |_key, value|
        table.add_row(AdminUI::Row.make_row(table.columns, value))
      end
      table
    end
  end
end
