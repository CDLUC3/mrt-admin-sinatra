# frozen_string_literal: true

require 'aws-sdk-cloudwatch'
require_relative '../uc3_client'

# Scope custom code for UC3 to distinguish from 3rd party classes
module UC3CloudWatch
  # Query for repository images by tag
  class MetricsClient < UC3::UC3Client
    def self.client
      UC3::UC3Client.clients.fetch(self.class.to_s, MetricsClient.new)
    end

    def initialize
      begin
        @cw_client = Aws::CloudWatch::Client.new
      rescue StandardError => e
        # puts e
        raise "Unable to load configuration data from S3: #{e}"
      end
      super(enabled: true)
    rescue StandardError => e
      # puts e
      super(enabled: false, message: e.to_s)
    end

    def metric_table(rows)
      cols = [
        AdminUI::Column.new(:timestamp, header: 'Timestamp')
      ]
      %w[aws-s3 sdsc wasabi].each do |cloud|
        %w[access audit].each do |method|
          cols << AdminUI::Column.new("#{cloud.gsub('-', '_')}_#{method}", header: "#{cloud} #{method}")
        end
      end
      table = AdminUI::FilterTable.new(
        columns: cols
      )
      rows.each do |row|
        table.add_row(AdminUI::Row.make_row(table.columns, row))
      end
      table
    end

    def metric_query(fname)
      query = []
      %w[aws-s3 sdsc wasabi].each do |cloud|
        %w[access audit].each do |method|
          query << {
            id: "#{cloud.gsub('-', '_')}_#{method}",
            metric_stat: {
              metric: {
                namespace: 'merritt',
                metric_name: 'retrieval-duration-sec',
                dimensions: [
                  { name: 'filename', value: fname },
                  { name: 'cloud_service', value: cloud },
                  { name: 'retrieval_method', value: method }
                ]
              },
              period: 60,
              stat: 'Average'
            },
            return_data: true
          }
        end
      end

      query
    end

    def retrieval_duration_sec_metrics
      return { message: 'CloudWatch client not configured' } unless enabled

      results = {}
      @cw_client.get_metric_data(
        metric_data_queries: metric_query('README.md'),
        start_time: Time.now - (24 * 3600),
        end_time: Time.now
      ).metric_data_results.each do |result|
        col = result.id
        result.timestamps.each_with_index do |tstamp, index|
          value = result.values[index]
          next unless value

          loctstamp = DateTime.parse(tstamp.to_s).to_time.localtime.strftime('%Y-%m-%d %H:%M:%S')

          results[loctstamp] ||= {}
          results[loctstamp][col] = value
        end
      end
      results.keys.sort.map do |tstamp|
        results[tstamp].merge({ timestamp: tstamp })
      end
    end
  end
end
