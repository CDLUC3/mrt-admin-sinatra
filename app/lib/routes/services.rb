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

    end

    def get_url(url)
      begin
        uri = URI.parse(url)
        response = Net::HTTP.get_response(uri)
        json = response.body
        content_type :json
        json
      rescue StandardError => e
        content_type :json
        { uri: uri, error: e.to_s }.to_json
      end
    end

  end
  register UC3ServicesRoutes
end
