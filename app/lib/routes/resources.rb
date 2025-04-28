# frozen_string_literal: true

require 'sinatra/base'
require_relative '../client/resources/instances'
require_relative '../client/resources/parameters'
require_relative '../client/resources/functions'
require_relative '../client/resources/elbs'
require_relative '../client/resources/buckets'
require_relative '../client/resources/ecs'
require_relative '../ui/context'

# custom sinatra routes
module Sinatra
  # client specific routes
  module UC3ResourcesRoutes
    def self.registered(app)
      app.get '/infra/instances' do
        erb :table,
          :layout => :page_layout,
          :locals => {
            context: AdminUI::Context.new(request.path),
            table: UC3Resources::InstancesClient.new.list_instances
          }
      end

      app.get '/infra/parameters' do
        erb :table,
          :layout => :page_layout,
          :locals => {
            context: AdminUI::Context.new(request.path),
            table: UC3Resources::ParametersClient.new.list_parameters
          }
      end

      app.get '/infra/buckets' do
        erb :table,
          :layout => :page_layout,
          :locals => {
            context: AdminUI::Context.new(request.path),
            table: UC3Resources::BucketsClient.new.list_buckets
          }
      end

      app.get '/infra/functions' do
        erb :table,
          :layout => :page_layout,
          :locals => {
            context: AdminUI::Context.new(request.path),
            table: UC3Resources::FunctionsClient.new.list_functions
          }
      end

      app.get '/infra/elbs' do
        erb :table,
          :layout => :page_layout,
          :locals => {
            context: AdminUI::Context.new(request.path),
            table: UC3Resources::LoadBalancerClient.new.list_instances
          }
      end

      app.get '/infra/ecs' do
        erb :table,
          :layout => :page_layout,
          :locals => {
            context: AdminUI::Context.new(request.path),
            table: UC3Resources::ServicesClient.new.list_services
          }
      end

      app.post '/infra/ecs/redeploy/*' do |service|
        UC3Resources::ServicesClient.new.redeploy_service(service)
        redirect '/infra/ecs'
      end


    end
  end
  register UC3ResourcesRoutes
end
