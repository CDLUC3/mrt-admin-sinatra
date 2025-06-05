# frozen_string_literal: true

require 'sinatra/base'
require 'net/http'
require_relative '../ui/context'

# custom sinatra routes
module Sinatra
  # client specific routes
  module UC3ServicesRoutes
    def self.registered(app)
      app.get '/json/ui/state' do
        get_url('http://ui:8086/state.json')
      end

      app.get '/json/ui/audit-replic' do
        get_url('http://ui:8086/state-audit-replic.json')
      end

      app.get '/json/ingest/state' do
        get_url('http://ingest:8080/ingest/state?t=json')
      end

      app.get '/json/ingest/tag' do
        get_url('http://ingest:8080/ingest/static/build.content.txt')
      end

      app.get '/json/store/state' do
        get_url('http://store:8080/store/state?t=json')
      end

      app.get '/json/store/tag' do
        get_url('http://store:8080/store/static/build.content.txt')
      end

      app.get '/json/store/nodes' do
        get_url('http://store:8080/store/jsonstatus')
      end

      app.get '/json/store/hostname' do
        get_url('http://store:8080/store/hostname')
      end

      app.get '/json/inventory/state' do
        get_url('http://inventory:8080/inventory/state?t=json')
      end

      app.post '/json/inventory/start' do
        post_url('http://inventory:8080/inventory/service/start?t=json')
      end

      app.post '/json/inventory/stop' do
        post_url('http://inventory:8080/inventory/service/stop?t=json')
      end

      app.get '/json/inventory/tag' do
        get_url('http://inventory:8080/inventory/static/build.content.txt')
      end

      app.get '/json/audit/state' do
        get_url('http://audit:8080/audit/state?t=json')
      end

      app.get '/json/audit/tag' do
        get_url('http://audit:8080/audit/static/build.content.txt')
      end

      app.get '/json/audit/nodes' do
        get_url('http://audit:8080/audit/jsonstatus')
      end

      app.post '/json/audit/start' do
        post_url('http://audit:8080/audit/service/start?t=json')
      end

      app.post '/json/audit/stop' do
        post_url('http://audit:8080/audit/service/stop?t=json')
      end

      app.get '/json/replic/state' do
        get_url('http://replic:8080/replic/state?t=json')
      end

      app.get '/json/replic/tag' do
        get_url('http://replic:8080/replic/static/build.content.txt')
      end

      app.post '/json/replic/start' do
        post_url('http://replic:8080/replic/service/start?t=json')
      end

      app.post '/json/replic/pause' do
        post_url('http://replic:8080/replic/service/pause?t=json')
      end

      app.get '/json/replic/nodes' do
        get_url('http://replic:8080/replic/jsonstatus')
      end

      app.get '/json/access/state' do
        get_url('http://access:8080/access/state?t=json')
      end

      app.get '/json/access/tag' do
        get_url('http://access:8080/access/static/build.content.txt')
      end

      app.get '/json/access/nodes' do
        get_url('http://access:8080/access/jsonstatus')
      end

      app.post '/stack-init' do
        stack_init
      end

    end

    def stack_init
      UC3::FileSystemClient.new.cleanup_ingest_folders
      resp = []
      resp << JSON.parse(post_url('http://inventory:8080/inventory/service/start?t=json'))
      resp << JSON.parse(post_url('http://replic:8080/replic/service/start?t=json'))
      resp << JSON.parse(post_url('http://audit:8080/audit/service/start?t=json'))
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
