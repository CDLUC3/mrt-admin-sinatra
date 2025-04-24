# frozen_string_literal: true

require 'aws-sdk-ssm'
require 'mustache'
require 'yaml'
require_relative '../ui/table'

# Scope custom code for UC3 to distinguish from 3rd party classes
module UC3
  # Base class for UC3 client classes
  class UC3Client
    @clients = {}

    def initialize(enabled: true, message: '')
      UC3Client.clients[self.class.to_s] = { name: self.class.to_s, enabled: enabled, message: message }
    end

    def date_format(date, convert_timezone: false)
      return '' if date.nil? || date.to_s.empty?
      d = DateTime.parse(date.to_s).to_time
      return '' if d.nil?
      d = d.localtime if convert_timezone
      d.strftime('%Y-%m-%d %H:%M:%S')
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

    class << self
      attr_reader :clients
    end

    def client_list
      table = AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:name, header: 'Client'),
          AdminUI::Column.new(:enabled, header: 'Enabled'),
          AdminUI::Column.new(:message, header: 'Message')
        ]
      )
      self.class.clients.sort.each do |_key, value|
        table.add_row(AdminUI::Row.make_row(table.columns, value))
      end
      table
    end

    def self.load_config(filename)
      config = YAML.safe_load_file(filename, aliases: true)
      JSON.parse(config.to_json, symbolize_names: true)
    end

    def self.lookup_map_by_filename(filename)
      map = YAML.safe_load_file(filename, aliases: true)
      lookup_map(map)
    end

    def self.lookup_map(map)
      ssm = Aws::SSM::Client.new(
        region: UC3::UC3Client.region
      )
      map.each do |key, value|
        if value.key?('ssm')
          resp = ssm.get_parameter(name: value['ssm'], with_decryption: true)
          map[key] = resp.parameter.value
        elsif value.key?('env')
          map[key] = ENV.fetch(value['env'], value.fetch('default', ''))
        elsif value.key?('val')
          map[key] = value['val']
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

    def self.resolve_lookup(filename, map)
      YAML.safe_load(Mustache.render(File.read(filename), map))
    end

    def self.semantic_tag?(tag)
      !(tag =~ /^\d+\.\d+\.\d+$/).nil?
    end

    def self.semantic_prefix_tag?(tag)
      !(tag =~ /^\d+\.\d+\.\d+(\..+)?$/).nil?
    end

    def self.deployed_tag?(tag, itags)
      arr = itags.clone
      arr << tag
      arr.each do |t|
        return true if t =~ /^(ecs-.*|dev|stg|prd|latest)$/
      end
      false
    end

    def self.keep_artifact_version?(v)
      v =~ /^\d+\.\d+-SNAPSHOT$/
    end

  end

  class FileSystemClient < UC3Client
    DIR = '/tdr/ingest/queue'
    def ingest_folders(params)
      path = params.fetch('path', '')
      path = "" if path =~ /^\.\./
      dir = path.empty? ? DIR : "#{DIR}/#{path}"

      table = AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:name, header: 'Name'),
          AdminUI::Column.new(:created, header: 'Created'),
          AdminUI::Column.new(:size, header: 'Bytes', cssclass: 'size'),
          AdminUI::Column.new(:actions, header: 'Actions'),
        ]
      )
      count = 0
      Dir.entries(dir).sort.each do |folder|
        next if folder == '.' || (folder == '..' && path.empty?)
        count += 1
        break if count > 1000
        
        if File.directory?("#{dir}/#{folder}")
          if folder == '..'
            data = {
              name: {value: '..', href: "/ops/zk/ingest/folders?path=#{File.dirname(path)}"},
              created: '',
              size: '',
              actions: []
            }
          else
            data = {
              name: {value: folder, href: "/ops/zk/ingest/folders?path=#{path}/#{folder}"},
              created: date_format(File.ctime("#{dir}/#{folder}")),
              size: '',
              actions: []
            }
          end
        else
          if folder =~ /(Estimate|Provision|Download|Process|Notify)_FAIL$/
            data = {
              name: folder,
              created: date_format(File.ctime("#{dir}/#{folder}")),
              size: File.size("#{dir}/#{folder}"),
              actions: {
                value: 'Delete',
                href: "/ops/zk/ingest/folder/delete",
                data: folder,
                cssclass: 'button',
                post: true,
                disabled: false
              }
            }
          else
            data = {
              name: folder,
              created: date_format(File.ctime("#{dir}/#{folder}")),
              size: File.size("#{dir}/#{folder}"),
              actions: []
            }
          end
        end
        table.add_row(AdminUI::Row.make_row(
          table.columns, 
          data
        ))
      end
      table
    end
  end
end
