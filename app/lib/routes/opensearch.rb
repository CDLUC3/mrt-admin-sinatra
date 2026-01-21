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

        adminui_show_table(
          AdminUI::Context.new(request.path, request.params),
          cli.task_listing(cli.task_query)
        )
      end

      app.get '/opensearch/tasks/history' do
        cli = UC3OpenSearch::OSClient.client
        label = request.params.fetch('label', '')

        adminui_show_table(
          AdminUI::Context.new(request.path, request.params),
          cli.task_history_listing(cli.task_history_query(label))
        )
      end
    end
  end
  register UC3OOpenSearchRoutes
end
