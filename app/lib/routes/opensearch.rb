# frozen_string_literal: true

require 'sinatra/base'
require_relative '../client/opensearch/opensearch'

# custom sinatra routes
module Sinatra
  # client specific routes
  module UC3OOpenSearchRoutes
    def self.registered(app)
      app.get '/opensearch/tasks' do
        cli = UC3OpenSearch::OSClient.client
        res = cli.task_query
        puts res.to_json if res.key?(:error)

        adminui_show_table(
          AdminUI::Context.new(request.path, request.params),
          cli.task_listing(res)
        )
      end

      app.get '/opensearch/tasks/history' do
        cli = UC3OpenSearch::OSClient.client
        label = request.params.fetch('label', '')
        res = cli.task_history_query(label)

        adminui_show_table(
          AdminUI::Context.new(request.path, request.params),
          cli.task_history_listing(res)
        )
      end

      app.get '/opensearch/logs/status_code/*' do |subservice|
        cli = UC3OpenSearch::OSClient.client
        res = cli.log_query(subservice, code: request.params.fetch('status_code', '400').to_i)
        puts res.to_json if res.key?(:error)

        adminui_show_table(
          AdminUI::Context.new(request.path, request.params),
          cli.log_query_listing(res)
        )
      end

      app.get '/opensearch/logs/level/*' do |subservice|
        cli = UC3OpenSearch::OSClient.client
        res = cli.log_level_query(subservice)
        puts res.to_json if res.key?(:error)

        adminui_show_table(
          AdminUI::Context.new(request.path, request.params),
          cli.log_query_listing(res, table: UC3OpenSearch::OSClient.log_level_table)
        )
      end
    end
  end
  register UC3OOpenSearchRoutes
end
