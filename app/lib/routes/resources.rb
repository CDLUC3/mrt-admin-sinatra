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
      AdminUI::Context.topmenu.create_menu_item_for_path(AdminUI::MENU_RESOURCES, '/instances', 'UC3 Instances')
      app.get '/instances' do
        erb :table,
          :layout => :page_layout,
          :locals => {
            context: AdminUI::Context.new(request.path),
            table: UC3Resources::InstancesClient.new.list_instances
          }
      end

      AdminUI::Context.topmenu.create_menu_item_for_path(AdminUI::MENU_RESOURCES, '/parameters', 'UC3 SSM Parameters')
      app.get '/parameters' do
        erb :table,
          :layout => :page_layout,
          :locals => {
            context: AdminUI::Context.new(request.path),
            table: UC3Resources::ParametersClient.new.list_parameters
          }
      end

      AdminUI::Context.topmenu.create_menu_item_for_path(AdminUI::MENU_RESOURCES, '/buckets', 'UC3 Buckets')
      app.get '/buckets' do
        erb :table,
          :layout => :page_layout,
          :locals => {
            context: AdminUI::Context.new(request.path),
            table: UC3Resources::BucketsClient.new.list_buckets
          }
      end

      AdminUI::Context.topmenu.create_menu_item_for_path(AdminUI::MENU_RESOURCES, '/functions', 'UC3 Lambda Functions')
      app.get '/functions' do
        erb :table,
          :layout => :page_layout,
          :locals => {
            context: AdminUI::Context.new(request.path),
            table: UC3Resources::FunctionsClient.new.list_functions
          }
      end

      AdminUI::Context.topmenu.create_menu_item_for_path(AdminUI::MENU_RESOURCES, '/elbs', 'Load Balancers')
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
