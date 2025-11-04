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

    def get_nodes
      data = {}
      UC3Query::QueryClient.client.query('/ops/storage/db/nodes', {}).table_data.each do |row|
        data[row[:node_number]] = "#{row[:node_number]} #{row[:description]} (#{row[:object_count]})"
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
      UC3Query::QueryClient.client.query('/ops/collections/list', {}).table_data.each do |row|
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
          AdminUI::Context.new(request.path, request.params),
          UC3Query::QueryClient.client.query('/queries/misc/admin-sla', {})
        )
      end

      app.post '/ops/collections/management/create-sla' do
        UC3S3::ConfigObjectsClient.client.create_sla(request.params)
        redirect '/ops/collections/management/slas'
      end

      app.get '/ops/collections/management/create-sla' do
        erb :colladmin_sla, layout: :page_layout, locals: {
          context: AdminUI::Context.new(request.path, request.params)
        }
      end

      app.get '/ops/collections/management/owners' do
        adminui_show_table(
          AdminUI::Context.new(request.path, request.params),
          UC3Query::QueryClient.client.query('/queries/misc/admin-owner', {})
        )
      end

      app.post '/ops/collections/management/create-owner' do
        UC3S3::ConfigObjectsClient.client.create_owner(request.params)
        redirect '/ops/collections/management/owners'
      end

      app.get '/ops/collections/management/create-owner' do
        erb :colladmin_owner, layout: :page_layout, locals: {
          context: AdminUI::Context.new(request.path, request.params),
          slas: get_slas
        }
      end

      app.get '/ops/collections/management/collections' do
        adminui_show_table(
          AdminUI::Context.new(request.path, request.params),
          UC3Query::QueryClient.client.query('/queries/misc/admin-collection', {})
        )
      end

      app.post '/ops/collections/management/create-collection' do
        ark = UC3S3::ConfigObjectsClient.client.create_collection(request.params)
        erb :colladmin_profile, layout: :page_layout, locals: {
          context: AdminUI::Context.new(request.path, request.params),
          profile: UC3S3::ConfigObjectsClient.client.make_profile(request.params, ark: ark),
          profile_name: "#{request.params.fetch('name', '')}_content"
        }
      end

      app.get '/ops/collections/management/create-collection' do
        erb :colladmin_collection, layout: :page_layout, locals: {
          context: AdminUI::Context.new(request.path, request.params),
          owners: get_owners,
          notifications: get_notification_map,
          nodes: get_nodes
        }
      end

      app.get '/ops/collections/management/profiles' do
        adminui_show_table(
          AdminUI::Context.new(request.path, request.params),
          UC3S3::ConfigObjectsClient.client.list_profiles
        )
      end

      app.get '/ops/collections/management/profiles/*' do |profile|
        content_type :text
        UC3S3::ConfigObjectsClient.client.get_profile(profile)
      end

      app.get '/saved-reports/list' do
        adminui_show_table(
          AdminUI::Context.new(request.path, request.params),
          UC3S3::ConfigObjectsClient.client.list_reports('reports/')
        )
      end

      app.get '/saved-reports/retrieve' do
        rpt = request.params.fetch('report', '')
        redirect '/saved-reports/list' if rpt.empty?

        rpt = URI.decode_www_form_component(rpt)

        redirect UC3S3::ConfigObjectsClient.client.get_report(rpt)
      end

      app.get '/saved-reports/url' do
        rpt = request.params.fetch('report', '')
        redirect '/saved-reports/list' if rpt.empty?

        rpt = URI.decode_www_form_component(rpt)

        adminui_show_table(
          AdminUI::Context.new(request.path, request.params),
          UC3S3::ConfigObjectsClient.client.get_report_url(rpt)
        )
      end
    end
  end
  register UC3S3Routes
end
