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
        adminui_show_table(
          AdminUI::Context.new(request.path),
          UC3Resources::InstancesClient.new.list_instances(request.params)
        )
      end

      app.get '/infra/parameters' do
        adminui_show_table(
          AdminUI::Context.new(request.path),
          UC3Resources::ParametersClient.new.list_parameters
        )
      end

      app.get '/infra/buckets' do
        adminui_show_table(
          AdminUI::Context.new(request.path),
          UC3Resources::BucketsClient.new.list_buckets
        )
      end

      app.get '/infra/functions' do
        adminui_show_table(
          AdminUI::Context.new(request.path),
          UC3Resources::FunctionsClient.new.list_functions
        )
      end

      app.get '/infra/elbs' do
        adminui_show_table(
          AdminUI::Context.new(request.path),
          UC3Resources::LoadBalancerClient.new.list_instances
        )
      end

      app.get '/infra/ecs' do
        adminui_show_table(
          AdminUI::Context.new(request.path),
          UC3Resources::ServicesClient.new.list_services
        )
      end

      app.post '/infra/ecs/redeploy/*' do |service|
        UC3Resources::ServicesClient.new.redeploy_service(service)
        redirect '/infra/ecs'
      end

      app.post '/infra/ecs/run/*/*' do |service, label|
        content_type :json
        UC3Resources::ServicesClient.new.run_service_task(service, label)
      end

      app.post '/infra/ecs/scale-up/*' do |service|
        UC3Resources::ServicesClient.new.scale_up_service(service)
        redirect '/infra/ecs'
      end

      app.post '/infra/ecs/scale-down/*' do |service|
        UC3Resources::ServicesClient.new.scale_down_service(service)
        redirect '/infra/ecs'
      end
    end
  end
  register UC3ResourcesRoutes
end
