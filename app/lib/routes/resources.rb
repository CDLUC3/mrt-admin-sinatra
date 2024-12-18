# frozen_string_literal: true

require 'sinatra/base'
require_relative '../client/resources/instances'
require_relative '../client/resources/parameters'
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

      app.get '/parameters' do
        erb :table,
          :layout => :page_layout,
          :locals => {
            context: AdminUI::Context.new("UC3 SSM Parameters"),
            table: UC3Resources::ParametersClient.new.list_parameters
          }
      end
    end
  end
  register UC3ResourcesRoutes
end
