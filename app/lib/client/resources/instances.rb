# frozen_string_literal: true

require 'aws-sdk-ec2'
require_relative '../uc3_client'

# Scope custom code for UC3 to distinguish from 3rd party classes
module UC3Resources
  # Query for repository images by tag
  class InstancesClient < UC3::UC3Client
    def initialize
      @client = Aws::EC2::Client.new(
        region: UC3::UC3Client::region
      )
      @client.describe_instances(filters: [{name: 'tag:foo', values: ['bar']}])
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
    def list_instances(filters: {})
      table = AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:name, header: 'Name'),
          AdminUI::Column.new(:id, header: 'ID'),
          AdminUI::Column.new(:service, header: 'Service'),
          AdminUI::Column.new(:subservice, header: 'Susbervice'),
          AdminUI::Column.new(:env, header: 'Environment'),
          AdminUI::Column.new(:type, header: 'Type'),
          AdminUI::Column.new(:state, header: 'State'),
          AdminUI::Column.new(:az, header: 'AZ')
        ],
        filters: [
          AdminUI::Filter.new('Running', 'running', match: true)
        ]
      )
      return table unless enabled
      instances = {}
      @client.describe_instances(filters: filters).reservations.each do |res|
        res.instances.each do |inst|
          name = inst.tags.find { |t| t.key == 'Name' }&.value
          instances[name] = {
            name: name,
            id: inst.instance_id,
            service: inst.tags.find { |t| t.key == 'Service' }&.value,
            subservice: inst.tags.find { |t| t.key == 'Subservice' }&.value,
            env: inst.tags.find { |t| t.key == 'Environment' }&.value,
            type: inst.instance_type,
            state: inst.state.name,
            az: inst.placement.availability_zone,
            cssclass: "data #{inst.state.name}"
          } 
        end
      end
      instances.sort.each do |key, value|
        table.add_row(AdminUI::Row.make_row(table.columns, value))
      end
    table
    end
  end
end
