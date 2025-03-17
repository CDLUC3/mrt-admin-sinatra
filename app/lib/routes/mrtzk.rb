# frozen_string_literal: true

require 'sinatra/base'
require 'uri'
require_relative '../client/zk/mrtzk'
require_relative '../ui/context'

# custom sinatra routes
module Sinatra
  # client specific routes
  module UC3ZKRoutes
    def self.registered(app)
      app.get '/ops/zk/nodes/node-names' do
        content_type :json
        zkcli = UC3Queue::ZKClient.new
        MerrittZK::NodeDump.new(zkcli.zk, request.params).listing.to_json
      end
      # tbd
    end
  end
  register UC3ZKRoutes
end
