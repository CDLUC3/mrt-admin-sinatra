# frozen_string_literal: true

require 'aws-sdk-s3'
require_relative '../uc3_client'

# Scope custom code for UC3 to distinguish from 3rd party classes
module UC3S3
  # Query for repository images by tag
  class ConfigObjectsClient < UC3::UC3Client
    def self.client
      UC3::UC3Client.clients.fetch(self.class.to_s, ConfigObjectsClient.new)
    end

    def initialize
      opt = {}
      opt[:region] = 'us-west-2'
      unless ENV.fetch('S3ENDPOINT', '').empty?
        opt[:endpoint] = ENV.fetch('S3ENDPOINT', '')
        opt[:credentials] = Aws::Credentials.new(
          ENV.fetch('S3ACCESSKEY', ''),
          ENV.fetch('S3SECRETKEY', '')
        )
        opt[:force_path_style] = true unless ENV.fetch('S3ENDPOINT', '').empty?
        # minio defaults to us-east-1
        opt[:region] = ENV.fetch('S3REGION', 'us-east-1')
      end

      @s3_client = Aws::S3::Client.new(opt)
      @prefix = ENV.fetch('S3CONFIG_PREFIX', 'uc3/mrt/mrt-ingest-profiles/')
      @bucket = ENV.fetch('S3CONFIG_BUCKET', 'mrt-config')

      puts "before get #{@prefix}index.yaml"
      resp = @s3_client.get_object(
        bucket: @bucket,
        key: "#{@prefix}index.yaml"
      )
      @config_objects = YAML.safe_load(resp.body.read, symbolize_names: true)

      super(enabled: true)
    rescue StandardError => e
      puts e
      super(enabled: false, message: e.to_s)
    end

    def enabled
      !@s3_client.nil?
    end

    def notification_map
      @config_objects.each_with_object({}) do |(key, value), map|
        map[key] = value[:Notification] if value[:Notification]
      end
    end

    def list_profiles
      table = AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:key, header: 'Profile Link'),
          AdminUI::Column.new(:Match, header: 'ProfileId Matches'),
          AdminUI::Column.new(:Owner, header: 'Owner'),
          AdminUI::Column.new(:StorageNode, header: 'StorageNode'),
          AdminUI::Column.new(:Priority, header: 'Priority'),
          AdminUI::Column.new(:ProfileDescription, header: 'ProfileDescription'),
          AdminUI::Column.new(:CallbackURL, header: 'CallbackURL'),
          AdminUI::Column.new(:error, header: 'Error')
        ]
      )
      return table unless enabled

      @config_objects.each do |key, value|
        value[:key] = {
          value: key,
          href: "/ops/collections/profiles/#{key}"
        }
        table.add_row(AdminUI::Row.make_row(table.columns, value))
      end
      table
    end

    def get_profile(profile)
      resp = @s3_client.get_object(
        bucket: @bucket,
        key: "#{@prefix}#{profile}"
      )
      resp.body.read
    rescue StandardError => e
      e.to_s
    end
  end
end
