# frozen_string_literal: true

require 'sinatra/base'
require_relative '../client/opensearch/opensearch'

# custom sinatra routes
module Sinatra
  # client specific routes
  module UC3OOpenSearchRoutes
    def self.registered(app)
      app.get '/opensearch/tasks' do
        content_type :json
        UC3OpenSearch::OSClient.client.query
      end
    end
  end
  register UC3OOpenSearchRoutes
end
