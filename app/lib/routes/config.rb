# frozen_string_literal: true

require 'sinatra/base'
require_relative '../client/s3/config_objects'

# custom sinatra routes
module Sinatra
  # client specific routes
  module UC3S3Routes
    def get_owners
      data = {}
      UC3Query::QueryClient.client.query('/queries/misc/owner', {}).table_data.each do |row|
        data[row[:ark]] = row[:name]
      end
      data
    end

    def get_slas
      data = {}
      UC3Query::QueryClient.client.query('/queries/misc/sla', {}).table_data.each do |row|
        data[row[:ark]] = row[:name]
      end
      data
    end

    def get_collections
      data = {}
      UC3Query::QueryClient.client.query('/queries/misc/collection', {}).table_data.each do |row|
        data[row[:ark]] = row[:name]
      end
      data
    end

    def get_notification_map
      UC3S3::ConfigObjectsClient.client.notification_map
    end

    def self.registered(app)
      app.get '/ops/collections/management/slas' do
        adminui_show_table(
          AdminUI::Context.new(request.path),
          UC3Query::QueryClient.client.query('/queries/misc/admin-sla', {})
        )
      end

      app.post '/ops/collections/management/create-sla' do
        redirect '/ops/collections/management/slas'
      end

      app.get '/ops/collections/management/create-sla' do
        erb :colladmin_sla, layout: :page_layout, locals: {
          context: AdminUI::Context.new(request.path)
        }
      end

      app.get '/ops/collections/management/owners' do
        adminui_show_table(
          AdminUI::Context.new(request.path),
          UC3Query::QueryClient.client.query('/queries/misc/admin-owner', {})
        )
      end

      app.post '/ops/collections/management/create-owner' do
        redirect '/ops/collections/management/owners'
      end

      app.get '/ops/collections/management/create-owner' do
        erb :colladmin_owner, layout: :page_layout, locals: {
          context: AdminUI::Context.new(request.path),
          slas: get_slas
        }
      end

      app.get '/ops/collections/management/collections' do
        adminui_show_table(
          AdminUI::Context.new(request.path),
          UC3Query::QueryClient.client.query('/queries/misc/admin-collection', {})
        )
      end


      app.post '/ops/collections/management/create-collection' do
        erb :colladmin_profile, layout: :page_layout, locals: {
          context: AdminUI::Context.new(request.path),
          profile: %{
# ${DESCRIPTION} - ${ARK}
ProfileID: ${NAME}
ProfileDescription: ${DESCRIPTION}
Identifier-scheme: ARK
Identifier-namespace: 13030
          }
        }              
      end

      app.get '/ops/collections/management/create-collection' do
        erb :colladmin_collection, layout: :page_layout, locals: {
          context: AdminUI::Context.new(request.path),
          owners: get_owners,
          notifications: get_notification_map
        }
      end

      app.get '/ops/collections/profiles' do
        adminui_show_table(
          AdminUI::Context.new(request.path),
          UC3S3::ConfigObjectsClient.client.list_profiles
        )
      end

      app.get '/ops/collections/profiles/*' do |profile|
        content_type :text
        UC3S3::ConfigObjectsClient.client.get_profile(profile)
      end
    end
  end
  register UC3S3Routes
end
