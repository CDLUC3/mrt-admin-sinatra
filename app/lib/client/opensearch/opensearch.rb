# frozen_string_literal: true

require 'opensearch-aws-sigv4'
require 'aws-sigv4'
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
        puts 'creating signer'
        signer = Aws::Sigv4::Signer.new(
          service: 'aoss', # Use 'aoss' for OpenSearch Serverless
          credentials_provider: Aws::CredentialProviderChain.new.resolve,
          region: ENV.fetch('AWS_REGION', 'us-west-2')
        )

        host = ENV.fetch('OPENSEARCH_ENDPOINT', '')
        # Initialize the OpenSearch client with the custom SigV4 signer
        puts "OS init for endpoint #{host}"

        @osclient = OpenSearch::Aws::Sigv4Client.new(
          {
            host: host,
            transport_options: {
              request: { timeout: 30 }
            }
          },
          signer
        )
        puts "OS client created for endpoint #{host}"
        @osclient.ping # Test the connection
        puts 'Ping succeeded'
      rescue StandardError => e
        # puts e
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

    def task_table
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

      table = task_table
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

      table = task_table
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
  end
end
