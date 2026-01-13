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

    def metric_table(rows, description: '')
      cols = [
        AdminUI::Column.new(:timestamp, header: 'Timestamp')
      ]
      %w[aws-s3 sdsc wasabi].each do |cloud|
        %w[access audit].each do |method|
          cols << AdminUI::Column.new("#{cloud.gsub('-', '_')}_#{method}", header: "#{cloud} #{method}")
        end
      end
      cols << AdminUI::Column.new(:status, header: 'Status')

      table = AdminUI::FilterTable.new(
        columns: cols,
        description: description
      )
      rows.each do |row|
        table.add_row(AdminUI::Row.make_row(table.columns, row))
      end
      table
    end

    def metric_query(fname, period_min: 15)
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
              period: period_min * 60,
              stat: 'Average'
            },
            return_data: true
          }
        end
      end

      query
    end

    def expected_retrieval_time_sec(fname)
      fsize = 0
      fsize = 100_000_000 if fname =~ /100_mb/
      fsize = 20_000_000 if fname =~ /20_mb/

      expected = {}
      %w[aws-s3 sdsc wasabi].each do |cloud|
        %w[access audit].each do |method|
          expected["#{cloud}_#{method}"] = benchmark_expected_retrieval_time_sec(fsize, cloud, method)
        end
      end
      expected
    end

    def retrieval_duration_sec_metrics(fname, period_min: 15, offset_days: 7)
      return { message: 'CloudWatch client not configured' } unless enabled

      results = {}
      next_token = nil

      starttime = Time.now - (offset_days * 24 * 3600)
      endtime = Time.now

      expected = expected_retrieval_time_sec(fname)

      loop do
        metresults = @cw_client.get_metric_data(
          metric_data_queries: metric_query(fname, period_min: period_min),
          start_time: starttime,
          end_time: endtime,
          next_token: next_token
        )

        next_token = metresults.next_token
        metresults.metric_data_results.each do |result|
          col = result.id
          result.timestamps.each_with_index do |tstamp, index|
            value = result.values[index]
            next unless value

            loctstamp = DateTime.parse(tstamp.to_s).to_time.localtime.strftime('%Y-%m-%d %H:%M:%S')

            results[loctstamp] ||= {}
            results[loctstamp][col] = value

            evalue = expected.fetch(col, 0)
            next if evalue.zero?

            results[loctstamp][:status] = 'FAIL' if value > 2 * evalue

            next if results[loctstamp][:status] == 'FAIL'

            results[loctstamp][:status] = 'WARN' if value > evalue

            next if results[loctstamp][:status] == 'WARN'

            # results[loctstamp][:status] = 'INFO' if value > evalue

            # next if results[loctstamp][:status] == 'INFO'

            results[loctstamp][:status] = 'PASS'
          end
        end

        break unless next_token
      end

      rows = []
      results.keys.sort.map do |tstamp|
        results[tstamp][:timestamp] = tstamp
        rows << results[tstamp]
      end
      rows
    end
  end
end
