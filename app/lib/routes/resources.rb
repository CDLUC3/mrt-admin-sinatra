# frozen_string_literal: true

require 'sinatra/base'
require_relative '../client/resources/instances'
require_relative '../client/resources/parameters'
require_relative '../client/resources/buckets'
require_relative '../client/resources/functions'
require_relative '../client/resources/elbs'
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

      AdminUI::Context.add_menu_item(AdminUI::MENU_RESOURCES, 'UC3 Buckets', '/buckets')
      app.get '/buckets' do
        erb :table,
          :layout => :page_layout,
          :locals => {
            context: AdminUI::Context.new(request.path),
            table: UC3Resources::BucketsClient.new.list_buckets
          }
      end

      AdminUI::Context.add_menu_item(AdminUI::MENU_RESOURCES, 'UC3 Lambda Functions', '/functions')
      app.get '/functions' do
        erb :table,
          :layout => :page_layout,
          :locals => {
            context: AdminUI::Context.new(request.path),
            table: UC3Resources::FunctionsClient.new.list_functions
          }
      end

      AdminUI::Context.add_menu_item(AdminUI::MENU_RESOURCES, 'Load Balancers', '/elbs')
      app.get '/elbs' do
        erb :table,
          :layout => :page_layout,
          :locals => {
            context: AdminUI::Context.new(request.path),
            table: UC3Resources::LoadBalancerClient.new.list_instances
          }
      end
    end
  end
  register UC3ResourcesRoutes
end
