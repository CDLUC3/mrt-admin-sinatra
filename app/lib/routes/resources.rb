# frozen_string_literal: true

require 'sinatra/base'
require_relative '../client/resources/instances'
require_relative '../ui/context'

# custom sinatra routes
module Sinatra
  # client specific routes
  module UC3ResourcesRoutes
    def self.registered(app)
      app.get '/instances' do
        erb :table,
          :layout => :page_layout,
          :locals => {
            context: AdminUI::Context.new("UC3 Instances"),
            table: UC3Resources::InstancesClient.new.list_instances
          }
      end
    end
  end
  register UC3ResourcesRoutes
end
