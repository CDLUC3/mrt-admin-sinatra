# frozen_string_literal: true

require 'aws-sdk-s3'
require_relative '../uc3_client'

# Scope custom code for UC3 to distinguish from 3rd party classes
module UC3Resources
  # Query for repository images by tag
  class BucketsClient < UC3::UC3Client
    def self.client
      UC3::UC3Client.clients.fetch(self.class.to_s, BucketsClient.new)
    end

    def initialize
      @client = Aws::S3::Client.new(
        region: UC3::UC3Client.region
      )
      @buckets = {}
      @client.list_buckets.buckets.each do |bucket|
        @buckets[bucket.name] = {
          name: bucket.name,
          created: date_format(bucket.creation_date, convert_timezone: true)
        }
      end
      super(enabled: enabled)
    rescue StandardError => e
      super(enabled: false, message: e.to_s)
    end

    def enabled
      !@client.nil?
    end

    def list_buckets
      table = AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:name, header: 'Name'),
          AdminUI::Column.new(:created, header: 'Created')
        ]
      )
      return table unless enabled

      @buckets.sort.each do |_key, value|
        table.add_row(AdminUI::Row.make_row(table.columns, value))
      end
      table
    end
  end
end
