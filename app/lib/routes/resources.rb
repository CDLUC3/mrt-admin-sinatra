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
          AdminUI::Context.new(request.path, request.params),
          UC3Resources::InstancesClient.new.list_instances(request.params)
        )
      end

      app.get '/infra/parameters' do
        adminui_show_table(
          AdminUI::Context.new(request.path, request.params),
          UC3Resources::ParametersClient.new.list_parameters
        )
      end

      app.get '/infra/buckets' do
        adminui_show_table(
          AdminUI::Context.new(request.path, request.params),
          UC3Resources::BucketsClient.new.list_buckets
        )
      end

      app.get '/infra/functions' do
        adminui_show_table(
          AdminUI::Context.new(request.path, request.params),
          UC3Resources::FunctionsClient.new.list_functions
        )
      end

      app.get '/infra/elbs' do
        adminui_show_table(
          AdminUI::Context.new(request.path, request.params),
          UC3Resources::LoadBalancerClient.new.list_instances
        )
      end

      app.get '/infra/ecs/services/state' do
        adminui_show_table(
          AdminUI::Context.new(request.path, request.params),
          UC3Resources::ServicesClient.new.list_services
        )
      end

      app.get '/infra/ecs/tasks/running' do
        adminui_show_table(
          AdminUI::Context.new(request.path, request.params),
          UC3Resources::ServicesClient.new.list_tasks
        )
      end

      app.get '/infra/ecs/tasks/scheduled' do
        adminui_show_table(
          AdminUI::Context.new(request.path, request.params),
          UC3Resources::ServicesClient.new.list_scheduled_tasks
        )
      end

      app.get '/infra/ecs/tasks/configured' do
        adminui_show_table(
          AdminUI::Context.new(request.path, request.params),
          UC3Resources::ServicesClient.new.list_task_definitions
        )
      end

      app.post '/infra/ecs/redeploy/*' do |service|
        UC3Resources::ServicesClient.new.redeploy_service(service)
        redirect '/infra/ecs/services/state'
      end

      app.post '/infra/ecs/deploy/*' do |service|
        UC3Resources::ServicesClient.new.deploy_service(service)
        redirect '/infra/ecs/services/state'
      end

      app.post '/infra/ecs/stop/*' do |service|
        UC3Resources::ServicesClient.new.stop_service(service)
        redirect '/infra/ecs/services/state'
      end

      app.post '/infra/ecs/tasks/launch/*/*' do |service, label|
        UC3Resources::ServicesClient.new.run_service_task(service, label)
        redirect '/infra/ecs/tasks/running'
      end

      app.post '/infra/ecs/scale-up/*' do |service|
        UC3Resources::ServicesClient.new.scale_up_service(service)
        redirect '/infra/ecs/services/state'
      end

      app.post '/infra/ecs/scale-down/*' do |service|
        UC3Resources::ServicesClient.new.scale_down_service(service)
        redirect '/infra/ecs/services/state'
      end
    end
  end
  register UC3ResourcesRoutes
end
