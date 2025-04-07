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
        erb :table,
          :layout => :page_layout,
          :locals => {
            context: AdminUI::Context.new(request.path),
            table: UC3Queue::ZKClient.new.dump_nodes(request.params)
          }
      end

      app.get '/ops/zk/ingest/batches' do
        erb :table,
          :layout => :page_layout,
          :locals => {
            context: AdminUI::Context.new(request.path),
            table: UC3Queue::ZKClient.new.batches
          }
      end

      app.get '/ops/zk/ingest/jobs-by-collection' do
        erb :table,
          :layout => :page_layout,
          :locals => {
            context: AdminUI::Context.new(request.path),
            table: UC3Queue::ZKClient.new.jobs_by_collection(request.params)
          }
      end

      app.get '/ops/zk/access/jobs' do
        erb :table,
          :layout => :page_layout,
          :locals => {
            context: AdminUI::Context.new(request.path),
            table: UC3Queue::ZKClient.new.assembly_requests
          }
      end
    end
  end
  register UC3ZKRoutes
end
