# frozen_string_literal: true

require 'sinatra/base'
require_relative '../client/query/query'
require_relative '../ui/context'

# custom sinatra routes
module Sinatra
  # client specific routes
  module UC3QueryRoutes
    def self.registered(app)
      UC3Query::QueryClient.client.create_menu_items

      app.get '/queries/*' do
        erb :table,
          layout: :page_layout,
          locals: {
            context: AdminUI::Context.new(request.path),
            table: UC3Query::QueryClient.client.query(request.path)
          }
      end
    end
  end
  register UC3QueryRoutes
end
