# frozen_string_literal: true

require 'opensearch-aws-sigv4'
require 'aws-sigv4'
require 'aws-sdk-sts'
require 'opensearch-ruby'
require_relative '../uc3_client'

# Scope custom code for UC3 to distinguish from 3rd party classes
module UC3OpenSearch
  # Query for repository images by tag
  class OSClient < UC3::UC3Client
    def self.client
      UC3::UC3Client.clients.fetch(self.class.to_s, OSClient.new)
    end

    def initialize
      begin
        signer = Aws::Sigv4::Signer.new(
          service: 'aoss', # Use 'aoss' for OpenSearch Serverless
          credentials_provider: Aws::CredentialProviderChain.new.resolve,
          region: ENV.fetch('AWS_REGION', 'us-west-2')
        )

        host = ENV.fetch('OPENSEARCH_ENDPOINT', '')

        # Initialize the OpenSearch client with the custom SigV4 signer

        @osclient = OpenSearch::Aws::Sigv4Client.new(
          {
            host: host,
            transport_options: {
              request: { timeout: 30 }
            }
          },
          signer
        )
        @osclient.ping # Test the connection
      rescue StandardError => e
        puts e
        raise "Unable to load configuration for OpenSearch: #{e}"
      end
      super(enabled: true)
    rescue StandardError => e
      # puts e
      super(enabled: false, message: e.to_s)
    end

    def index_name
      "mrt-#{UC3::UC3Client.stack_name}-logs"
    end

    def task_query
      @osclient.search(
        index: index_name,
        body: {
          query: {
            exists: {
              field: 'event.json.task_status'
            }
          },
          sort: [
            { '@timestamp': { order: 'asc' } }
          ],
          size: 1000
        }
      )
    rescue StandardError => e
      { error: e.to_s }
    end

    def self.task_table
      AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new('task_label', header: 'Task Label'),
          AdminUI::Column.new('task_datetime', header: 'Task Datetime'),
          AdminUI::Column.new('task_status', header: 'Task Status'),
          AdminUI::Column.new('task_duration', header: 'Task Duration'),
          AdminUI::Column.new('task_environment', header: 'Task Environment'),
          AdminUI::Column.new('log', header: 'Logs')
        ]
      )
    end

    def make_result(hit, link_label: false)
      source = hit.fetch('_source', {})
      cwlogs = source.fetch('cwlogs', {})
      res = hit.fetch('_source', {}).fetch('event', {}).fetch('json', {})
      res[:label] = res.fetch('task_label', '')
      res['log'] = {
        value: 'logs',
        href: UC3::UC3Client.cloudwatch_stream(cwlogs.fetch('logGroup', ''), cwlogs.fetch('logStream', ''))
      }
      if link_label
        res['task_label'] = {
          value: res[:label],
          href: "/opensearch/tasks/history?label=#{CGI.escape(res[:label])}"
        }
      end
      res
    end

    def task_listing(osres)
      results = {}
      osres.fetch('hits', {}).fetch('hits', []).each do |hit|
        res = make_result(hit, link_label: true)
        results[res[:label]] = res
      end

      table = UC3OpenSearch::OSClient.task_table
      results.values.sort_by { |task| task.fetch('task_datetime', '') }.reverse.each do |task|
        table.add_row(
          AdminUI::Row.make_row(
            table.columns,
            task
          )
        )
      end
      table
    end

    def task_history_query(label)
      @osclient.search(
        index: index_name,
        body: {
          query: {
            match_phrase: {
              'event.json.task_label': label.to_s
            }
          },
          sort: [
            { '@timestamp': { order: 'desc' } }
          ],
          size: 20
        }
      )
    rescue StandardError => e
      { error: e.to_s }
    end

    def task_history_listing(osres)
      results = osres.fetch('hits', {}).fetch('hits', []).map do |hit|
        make_result(hit)
      end

      table = UC3OpenSearch::OSClient.task_table
      results.each do |task|
        table.add_row(
          AdminUI::Row.make_row(
            table.columns,
            task
          )
        )
      end
      table
    end

    def log_query(subservice, code: 400)
      @osclient.search(
        index: index_name,
        body: {
          query: {
            bool: {
              must: [
                { match: { 'merritt.subservice': subservice } },
                { range: { 'http.response.status_code': { gte: code } } }
              ]
            }
          },
          sort: [
            { '@timestamp': { order: 'desc' } }
          ],
          size: 1000
        }
      )
    rescue StandardError => e
      { error: e.to_s }
    end

    def log_level_query(subservice)
      @osclient.search(
        index: index_name,
        body: {
          query: {
            bool: {
              must: [
                { match: { 'merritt.subservice': subservice } }
              ],
              should: [
                { match: { 'merritt.log_level': 'WARN' } },
                { match: { 'merritt.log_level': 'WARNING' } },
                { match: { 'merritt.log_level': 'ERROR' } },
                { match: { 'merritt.log_level': 'SEVERE' } }
              ],
              minimum_should_match: 1
            }
          },
          sort: [
            { '@timestamp': { order: 'desc' } }
          ],
          size: 250
        }
      )
    rescue StandardError => e
      { error: e.to_s }
    end

    def self.log_table
      AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new('timestamp', header: 'Timestamp'),
          AdminUI::Column.new('record_type', header: 'Record Type', filterable: true),
          AdminUI::Column.new('path', header: 'Path'),
          AdminUI::Column.new('status_code', header: 'Status Code', filterable: true),
          AdminUI::Column.new('log', header: 'Logs')
        ]
      )
    end

    def self.log_level_table
      AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new('timestamp', header: 'Timestamp'),
          AdminUI::Column.new('record_type', header: 'Record Type', filterable: true),
          AdminUI::Column.new('level', header: 'Level', filterable: true),
          AdminUI::Column.new('message', header: 'Message'),
          AdminUI::Column.new('log', header: 'Logs')
        ]
      )
    end

    def make_log_result(hit)
      res = {}
      source = hit.fetch('_source', {})
      cwlogs = source.fetch('cwlogs', {})
      merritt = source.fetch('merritt', {})
      res['timestamp'] = DateTime.parse(source.fetch('@timestamp', '')).to_time.localtime.strftime('%Y-%m-%d %H:%M:%S')
      res['record_type'] = merritt.fetch('record_type', '')
      res['level'] = merritt.fetch('log_level', '')
      # res['level'] = source.fetch('event', {}).fetch('json', {}).fetch('log.level', '') if res['level'].empty?
      res['path'] = source.fetch('url', {}).fetch('original', '').to_s
      message = source.fetch('message', '')
      evmessage = source.fetch('event', {}).fetch('json', {}).fetch('message', '')
      errmessage = source.fetch('event', {}).fetch('json', {}).fetch('error', {}).fetch('message', '').to_s
      res['message'] = errmessage
      res['message'] = evmessage if res['message'].empty?
      res['message'] = message if res['message'].empty?
      res['message'] = res['path'] if res['message'].empty?
      res['status_code'] = source.fetch('http', {}).fetch('response', {}).fetch('status_code', 0)
      res['log'] = {
        value: 'logs',
        href: UC3::UC3Client.cloudwatch_stream(cwlogs.fetch('logGroup', ''), cwlogs.fetch('logStream', ''))
      }
      res
    end

    def log_query_listing(osres, table: UC3OpenSearch::OSClient.log_table)
      results = osres.fetch('hits', {}).fetch('hits', []).map do |hit|
        make_log_result(hit)
      end

      results.each do |rec|
        table.add_row(
          AdminUI::Row.make_row(
            table.columns,
            rec
          )
        )
      end
      table
    end
  end
end
