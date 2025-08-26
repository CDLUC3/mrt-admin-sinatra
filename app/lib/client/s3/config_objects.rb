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

      puts "Before create client"
      @s3_client = Aws::S3::Client.new(opt)
      puts "After create client #{@s3_client.inspect}"
      @prefix = ENV.fetch('S3CONFIG_PREFIX', 'uc3/mrt/mrt-ingest-profiles/')
      @bucket = ENV.fetch('S3CONFIG_BUCKET', 'mrt-config')
      opts = {
        bucket: @bucket,
        prefix: @prefix
      }
      token = :first
      @config_objects = []
      until token.nil?
        resp = @s3_client.list_objects_v2(opts)
        resp.contents.each do |s3obj|
          @config_objects << {
            key: {
              value: s3obj.key[@prefix.length..],
              href: "/ops/collections/profiles/#{s3obj.key[@prefix.length..]}"
            }
          }
        end
        token = resp.next_continuation_token
        opts[:continuation_token] = token
      end
      super(enabled: true)
    rescue StandardError => e
      puts e
      super(enabled: false, message: e.to_s)
    end

    def enabled
      !@s3_client.nil?
    end

    def list_profiles
      table = AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:key, header: 'Key')
        ]
      )
      return table unless enabled

      @config_objects.each do |value|
        table.add_row(AdminUI::Row.make_row(table.columns, value))
      end
      table
    end

    def get_profile(profile)
      resp = @s3_client.get_object(
        bucket: @bucket,
        key: "uc3/mrt/mrt-ingest-profiles/#{profile}"
      )
      resp.body.read
    rescue StandardError => e
      e.to_s
    end
  end
end
