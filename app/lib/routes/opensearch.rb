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
    end
  end
  register UC3OOpenSearchRoutes
end
