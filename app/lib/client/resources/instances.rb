# frozen_string_literal: true

require 'aws-sdk-ec2'
require 'net/http'
require_relative '../uc3_client'

# Scope custom code for UC3 to distinguish from 3rd party classes
module UC3Resources
  # Query for repository images by tag
  class InstancesClient < UC3::UC3Client
    def self.client
      UC3::UC3Client.clients.fetch(self.class.to_s, InstancesClient.new)
    end

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
    def list_instances(params)
      filters = []
      program = params.fetch('program', '')
      service = params.fetch('service', '')
      unless program.empty?
        filters << {
          name: 'tag:Program',
          values: [program]
        }
      end
      unless service.empty?
        filters << {
          name: 'tag:Service',
          values: [service]
        }
      end
      envfilt = ENV.fetch('SSM_ROOT_PATH', '').split('/')
      unless envfilt.empty?
        filters << {
          name: 'tag:Environment',
          values: [envfilt[-1]]
        }
      end
      table = AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:servername, header: 'Name'),
          AdminUI::Column.new(:program, header: 'Program', filterable: true),
          AdminUI::Column.new(:service, header: 'Service', filterable: true),
          AdminUI::Column.new(:subservice, header: 'Susbervice', filterable: true),
          AdminUI::Column.new(:env, header: 'Environment', filterable: true),
          AdminUI::Column.new(:type, header: 'Type', filterable: true),
          AdminUI::Column.new(:state, header: 'State', filterable: true),
          AdminUI::Column.new(:az, header: 'AZ', filterable: true),
          AdminUI::Column.new(:data, header: 'Server Data')
        ]
      )
      return table unless enabled

      instances = {}
      @client.describe_instances({ filters: filters }).reservations.each do |res|
        res.instances.each do |inst|
          name = inst.tags.find { |t| t.key == 'Name' }&.value
          instances[name] = {
            servername: [ name, inst.instance_id, date_format(inst.launch_time, convert_timezone: true) ],
            program: inst.tags.find { |t| t.key == 'Program' }&.value,
            service: inst.tags.find { |t| t.key == 'Service' }&.value,
            subservice: inst.tags.find { |t| t.key == 'Subservice' }&.value,
            env: inst.tags.find { |t| t.key == 'Environment' }&.value,
            type: inst.instance_type,
            state: inst.state.name,
            az: inst.placement.availability_zone,
            cssclass: "data #{inst.state.name}",
          }
          instances[name][:data] = get_data(name, instances[name]) if service == 'mrt'
        end
      end
      instances.sort.each do |_key, value|
        table.add_row(AdminUI::Row.make_row(table.columns, value))
      end
      table
    end

    # this is cloned from services.rb...
    def get_url(url, ctype: :json)
      uri = URI.parse(url)
      response = Net::HTTP.get_response(uri)
      data = response.body
      content_type ctype
      data
    rescue StandardError => e
      content_type :json
      { uri: uri, error: e.to_s }.to_json
    end

    def get_data(name,instance)
      subservice = instance[:subservice]
      if subservice == 'ingest'
        return get_url("https://#{name}:33121/static/build.content.txt", ctype: :text)
      elsif subservice == 'audit'
        return get_url("https://#{name}:37001/static/build.content.txt", ctype: :text)
      elsif subservice == 'inventory'
        return get_url("https://#{name}:36121/static/build.content.txt", ctype: :text)
      elsif subservice == 'replic'
        return get_url("https://#{name}:38001/static/build.content.txt", ctype: :text)
      elsif subservice == 'store'
        return get_url("https://#{name}:35121/static/build.content.txt", ctype: :text)
      elsif subservice == 'access'
        return get_url("https://#{name}:35121/static/build.content.txt", ctype: :text)
      elsif subservice == 'ui'
        return JSON.parse(get_url("https://#{name}:26181/static/state", ctype: :json))['version']
      end
    end
  end
end
