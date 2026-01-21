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

    def task_query
      @osclient.search(
        index: 'mrt-ecs-dev-logs',
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

    def task_listing(osres)
      res = {}
      osres.fetch('hits', {}).fetch('hits', []).each do |hit|
        json = hit.fetch('_source', {}).fetch('event', {}).fetch('json', {})
        res[json.fetch('task_label', '')] = json
      end

      table = AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new('task_label', header: 'Task Label'),
          AdminUI::Column.new('task_datetime', header: 'Task Datetime'),
          AdminUI::Column.new('task_status', header: 'Task Status'),
          AdminUI::Column.new('task_duration', header: 'Task Duration'),
          AdminUI::Column.new('task_environment', header: 'Task Environment')
        ]
      )
      res.values.sort_by { |task| task.fetch('task_datetime', '') }.reverse.each do |task|
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
