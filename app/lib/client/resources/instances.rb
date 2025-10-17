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
            servername: [name, inst.instance_id, date_format(inst.launch_time, convert_timezone: true)],
            program: inst.tags.find { |t| t.key == 'Program' }&.value,
            service: inst.tags.find { |t| t.key == 'Service' }&.value,
            subservice: inst.tags.find { |t| t.key == 'Subservice' }&.value,
            env: inst.tags.find { |t| t.key == 'Environment' }&.value,
            type: inst.instance_type,
            state: inst.state.name,
            az: inst.placement.availability_zone,
            cssclass: "data #{inst.state.name}"
          }
          instances[name][:data] = get_merritt_data(name, instances[name]) if service == 'mrt'
        end
      end
      instances.sort.each do |_key, value|
        table.add_row(AdminUI::Row.make_row(table.columns, value))
      end
      table
    end

    # this is cloned from services.rb...
    def get_url_body(url)
      uri = URI.parse(url)
      response = Net::HTTP.get_response(uri)
      response.body
    rescue StandardError
      ''
    end

    def get_url_json(url)
      uri = URI.parse(url)
      response = Net::HTTP.get_response(uri)
      JSON.parse(response.body)
    rescue StandardError
      {}
    end

    def get_merritt_data(name, instance)
      subservice = instance[:subservice]
      case subservice
      when 'ingest'
        get_url_body("http://#{name}.cdlib.org:33121/static/build.content.txt")
      when 'audit'
        get_url_body("http://#{name}.cdlib.org:37001/static/build.content.txt")
      when 'inventory'
        get_url_body("http://#{name}.cdlib.org:36121/static/build.content.txt")
      when 'replic'
        get_url_body("http://#{name}.cdlib.org:38001/static/build.content.txt")
      when 'store'
        get_url_body("http://#{name}.cdlib.org:35121/static/build.content.txt")
      when 'access'
        get_url_body("http://#{name}.cdlib.org:35121/static/build.content.txt")
      when 'ui'
        get_url_json("http://#{name}.cdlib.org:26181/state.json").fetch('version', '')
      end
    end
  end
end
