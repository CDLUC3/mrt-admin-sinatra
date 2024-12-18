# frozen_string_literal: true

require 'aws-sdk-ec2'
require_relative '../uc3_client'

# Scope custom code for UC3 to distinguish from 3rd party classes
module UC3Resources
  # Query for repository images by tag
  class ParametersClient < UC3::UC3Client
    def initialize
      @client = Aws::SSM::Client.new(
        region: UC3::UC3Client::region
      )
      @client.get_parameters_by_path(path: '/uc3/foo/bar')
      super(enabled)
    rescue StandardError => e
      super(false, message: e.to_s)
    end

    def enabled
      !@client.nil?
    end

    # filters: [
    # {
    #   name: 'tag:Program',
    #   values: ['uc3']
    # },
    # {
    #   name: 'tag:Environment',
    #   values: ['dev']
    # }
    # ]
    def list_parameters(filters: {})
      table = AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:path, header: 'Path'),
          AdminUI::Column.new(:type, header: 'Type'),
          AdminUI::Column.new(:value, header: 'Value'),
          AdminUI::Column.new(:modified, header: 'Modified'),
          AdminUI::Column.new(:version, header: 'Version')
        ]
      )
      return table unless enabled
      params = {}

      next_token = 'na'
      opt = {path: '/uc3', recursive: true}
      while next_token
        res = @client.get_parameters_by_path(opt)
        res.parameters.each do |param|
          path = param.name
          params[path] = {
            path: path,
            type: param.type,
            value: param.type == 'SecureString' ? '***' : param.value,
            modified: param.last_modified_date,
            version: param.version
          }
        end
        next_token = res.next_token
        opt[:next_token] = next_token
      end
      params.sort.each do |key, value|
        table.add_row(AdminUI::Row.make_row(table.columns, value))
      end
    table
    end
  end
end
