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

      AdminUI::Context.add_menu_item(AdminUI::MENU_RESOURCES, 'Resources')
      AdminUI::Context.add_menu_item(AdminUI::MENU_RESOURCES, 'UC3 Instances', '/instances')
      app.get '/instances' do
        erb :table,
          :layout => :page_layout,
          :locals => {
            context: AdminUI::Context.new(request.path),
            table: UC3Resources::InstancesClient.new.list_instances
          }
      end

      AdminUI::Context.add_menu_item(AdminUI::MENU_RESOURCES, 'UC3 SSM Parameters', '/parameters')
      app.get '/parameters' do
        erb :table,
          :layout => :page_layout,
          :locals => {
            context: AdminUI::Context.new(request.path),
            table: UC3Resources::ParametersClient.new.list_parameters
          }
      end
    end
  end
  register UC3ResourcesRoutes
end
