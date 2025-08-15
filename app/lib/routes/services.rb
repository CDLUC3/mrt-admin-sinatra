# frozen_string_literal: true

require 'sinatra/base'
require 'net/http'
require_relative '../ui/context'

# custom sinatra routes
module Sinatra
  # client specific routes
  module UC3ServicesRoutes
    def ui_host
      host = ENV.fetch('SVC_UI', 'ui:8086')
      host =~ /^http/ ? host : "http://#{host}"  
    end

    def ingest_host
      "http://#{ENV.fetch('SVC_INGEST', 'ingest:8080/ingest')}"
    end

    def store_host
      "http://#{ENV.fetch('SVC_STORE', 'store:8080/store')}"
    end

    def access_host
      "http://#{ENV.fetch('SVC_ACCESS', 'access:8080/store')}"
    end

    def audit_host
      "http://#{ENV.fetch('SVC_AUDIT', 'audit:8080/audit')}"
    end

    def replic_host
      "http://#{ENV.fetch('SVC_REPLIC', 'replic:8080/replic')}"
    end

    def inventory_host
      "http://#{ENV.fetch('SVC_INVENTORY', 'inventory:8080/inventory')}"
    end

    def self.registered(app)
      app.get '/json/ui/state' do
        get_url("#{ui_host}/state.json")
      end

      app.get '/json/ui/audit-replic' do
        get_url("#{ui_host}/state-audit-replic.json")
      end

      app.get '/json/ingest/state' do
        get_url("#{ingest_host}/state?t=json")
      end

      app.get '/json/ingest/tag' do
        get_url("#{ingest_host}/static/build.content.txt")
      end

      app.get '/json/store/state' do
        get_url("#{store_host}/state?t=json")
      end

      app.get '/json/store/tag' do
        get_url("#{store_host}/static/build.content.txt")
      end

      app.get '/json/access/state' do
        get_url("#{access_host}/state?t=json")
      end

      app.get '/json/access/tag' do
        get_url("#{access_host}/static/build.content.txt")
      end

      app.get '/json/store/nodes' do
        get_url("#{store_host}/jsonstatus")
      end

      app.get '/json/store/hostname' do
        get_url("#{store_host}/hostname")
      end

      app.get '/json/inventory/state' do
        get_url("#{inventory_host}/state?t=json")
      end

      app.post '/json/inventory/start' do
        post_url("#{inventory_host}/service/start?t=json")
      end

      app.post '/json/inventory/stop' do
        post_url("#{inventory_host}/service/stop?t=json")
      end

      app.post '/json/inventory/admin-init' do
        post_url("#{inventory_host}/service/admin/init")
      end

      app.get '/json/inventory/tag' do
        get_url("#{inventory_host}/static/build.content.txt")
      end

      app.get '/json/audit/state' do
        get_url("#{audit_host}/state?t=json")
      end

      app.get '/json/audit/tag' do
        get_url("#{audit_host}/static/build.content.txt")
      end

      app.get '/json/audit/nodes' do
        get_url("#{audit_host}/jsonstatus")
      end

      app.post '/json/audit/start' do
        post_url("#{audit_host}/service/start?t=json")
      end

      app.post '/json/audit/stop' do
        post_url("#{audit_host}/service/stop?t=json")
      end

      app.get '/json/replic/state' do
        get_url("#{replic_host}/state?t=json")
      end

      app.get '/json/replic/tag' do
        get_url("#{replic_host}/static/build.content.txt")
      end

      app.post '/json/replic/start' do
        post_url("#{replic_host}/service/start?t=json")
      end

      app.post '/json/replic/pause' do
        post_url("#{replic_host}/service/pause?t=json")
      end

      app.get '/json/replic/nodes' do
        get_url("#{replic_host}/jsonstatus")
      end

      app.get '/json/access/state' do
        get_url("#{access_host}/state?t=json")
      end

      app.get '/json/access/tag' do
        get_url("#{access_host}/static/build.content.txt")
      end

      app.get '/json/access/nodes' do
        get_url("#{access_host}/jsonstatus")
      end

      app.post '/stack-init' do
        stack_init
      end
    end

    def stack_init
      UC3::FileSystemClient.client.cleanup_ingest_folders
      resp = []
      resp << ::JSON.parse(post_url("#{inventory_host}/service/start?t=json"))
      resp << ::JSON.parse(post_url("#{replic_host}/service/start?t=json"))
      resp << ::JSON.parse(post_url("#{audit_host}/service/start?t=json"))
      resp.to_json
    end

    def get_url(url)
      uri = URI.parse(url)
      response = Net::HTTP.get_response(uri)
      json = response.body
      content_type :json
      json
    rescue StandardError => e
      content_type :json
      { uri: uri, error: e.to_s }.to_json
    end

    def post_url(url)
      uri = URI.parse(url)
      req = Net::HTTP::Post.new(uri)
      req.content_type = 'application/json'
      response = Net::HTTP.start(uri.hostname, uri.port) do |http|
        http.request(req)
      end
      json = response.body
      content_type :json
      json
    rescue StandardError => e
      content_type :json
      { uri: uri, error: e.to_s }.to_json
    end
  end
  register UC3ServicesRoutes
end
