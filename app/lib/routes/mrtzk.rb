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

      app.get '/ops/zk/ingest/pause' do
        UC3Queue::ZKClient.new.pause_ingest
        redirect '/ops/zk/nodes/node-names?zkpath=/locks&mode=node'
      end

      app.get '/ops/zk/ingest/unpause' do
        UC3Queue::ZKClient.new.unpause_ingest
        redirect '/ops/zk/nodes/node-names?zkpath=/locks&mode=node'
      end

      app.get '/ops/zk/ingest/cleanup-queue' do
        UC3Queue::ZKClient.new.cleanup_ingest_queue
        redirect '/ops/zk/nodes/node-names?zkpath=/batches&mode=node'
      end

      app.get '/ops/zk/access/pause-small' do
        UC3Queue::ZKClient.new.pause_access_small
        redirect '/ops/zk/nodes/node-names?zkpath=/locks&mode=node'
      end

      app.get '/ops/zk/access/unpause-small' do
        UC3Queue::ZKClient.new.unpause_access_small
        redirect '/ops/zk/nodes/node-names?zkpath=/locks&mode=node'
      end

      app.get '/ops/zk/access/pause-large' do
        UC3Queue::ZKClient.new.pause_access_large
        redirect '/ops/zk/nodes/node-names?zkpath=/locks&mode=node'
      end

      app.get '/ops/zk/access/unpause-large' do
        UC3Queue::ZKClient.new.unpause_access_large
        redirect '/ops/zk/nodes/node-names?zkpath=/locks&mode=node'
      end

      app.get '/ops/zk/access/cleanup-queue' do
        UC3Queue::ZKClient.new.cleanup_access_queue
        redirect '/ops/zk/nodes/node-names?zkpath=/access&mode=node'
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
