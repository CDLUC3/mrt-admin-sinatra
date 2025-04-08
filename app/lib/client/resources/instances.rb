# frozen_string_literal: true

require 'aws-sdk-ec2'
require_relative '../uc3_client'

# Scope custom code for UC3 to distinguish from 3rd party classes
module UC3Resources
  # Query for repository images by tag
  class InstancesClient < UC3::UC3Client
    def initialize
      @client = Aws::EC2::Client.new(
        region: UC3::UC3Client.region
      )
      @client.describe_instances(filters: [{ name: 'tag:foo', values: ['bar'] }])
      super(enabled: enabled)
    rescue StandardError => e
      super(enabled: false, message: e.to_s)
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
          AdminUI::Column.new(:program, header: 'Program', filterable: true),
          AdminUI::Column.new(:service, header: 'Service', filterable: true),
          AdminUI::Column.new(:subservice, header: 'Susbervice', filterable: true),
          AdminUI::Column.new(:env, header: 'Environment', filterable: true),
          AdminUI::Column.new(:type, header: 'Type', filterable: true),
          AdminUI::Column.new(:state, header: 'State', filterable: true),
          AdminUI::Column.new(:launch, header: 'Launch'),
          AdminUI::Column.new(:az, header: 'AZ', filterable: true)
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
            program: inst.tags.find { |t| t.key == 'Program' }&.value,
            service: inst.tags.find { |t| t.key == 'Service' }&.value,
            subservice: inst.tags.find { |t| t.key == 'Subservice' }&.value,
            env: inst.tags.find { |t| t.key == 'Environment' }&.value,
            type: inst.instance_type,
            launch: date_format(inst.launch_time, convert_timezone: true),
            state: inst.state.name,
            az: inst.placement.availability_zone,
            cssclass: "data #{inst.state.name}"
          }
        end
      end
      instances.sort.each do |_key, value|
        table.add_row(AdminUI::Row.make_row(table.columns, value))
      end
      table
    end
  end
end
