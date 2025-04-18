# frozen_string_literal: true

require 'sinatra/base'
require 'uri'
require_relative '../client/query/query'
require_relative '../ui/context'

# custom sinatra routes
module Sinatra
  # client specific routes
  module UC3QueryRoutes
    def self.registered(app)
      app.get '/queries/repository' do
        erb :none,
          :layout => :page_layout,
          :locals => {
            context: AdminUI::Context.new(request.path)
          }
      end

      app.get '/queries/consistency' do
        erb :none,
          :layout => :page_layout,
          :locals => {
            context: AdminUI::Context.new(request.path)
          }
      end

      app.get '/queries/repository/object*' do
        erb :tables,
          layout: :page_layout,
          locals: {
            context: AdminUI::Context.new(request.path),
            table: UC3Query::QueryClient.client.query(request.path, request.params),
            aux_tables: [
              UC3Query::QueryClient.client.query(request.path, request.params, sqlsym: :repl_sql),
              UC3Query::QueryClient.client.query(request.path, request.params, sqlsym: :files_sql)
            ]
          }
      end

      app.get '/queries/update-billing' do
        UC3Query::QueryClient.client.update_billing
        redirect '/queries/repository/collections/bytes'
      end

      app.get '/queries/recent/ingests/today' do
        redirect "/queries/recent/ingests?date=#{Date.today.strftime('%Y-%m-%d')}"
      end

      app.get '/queries/content/producer-files' do
        if request.params.key?('mnemonic')
          erb :table,
            layout: :page_layout,
            locals: {
              context: AdminUI::Context.new(request.path),
              table: UC3Query::QueryClient.client.query(request.path, request.params)
            }
        else
          erb :table,
            layout: :page_layout,
            locals: {
              context: AdminUI::Context.new(request.path),
              table: UC3Query::QueryClient.client.query('/queries/collections', request.params)
            }
        end
      end

      app.get '/queries/content/ucsc-objects' do
        if request.params.key?('mnemonic')
          erb :table,
            layout: :page_layout,
            locals: {
              context: AdminUI::Context.new(request.path),
              table: UC3Query::QueryClient.client.query(request.path, request.params)
            }
        else
          erb :table,
            layout: :page_layout,
            locals: {
              context: AdminUI::Context.new(request.path),
              table: UC3Query::QueryClient.client.query('/queries/collections', request.params)
            }
        end
      end

      app.get '/queries/**' do
        request.params[:term] = URI.decode_www_form_component(request.params[:term]) if request.params.key?(:term)
        erb :table,
          layout: :page_layout,
          locals: {
            context: AdminUI::Context.new(request.path),
            table: UC3Query::QueryClient.client.query(request.path, request.params)
          }
      end

      app.get '/ops/db-queue/**' do
        erb :table,
          layout: :page_layout,
          locals: {
            context: AdminUI::Context.new(request.path),
            table: UC3Query::QueryClient.client.query(request.path, request.params)
          }
      end

      app.get '/ops/collections/db/**' do
        erb :table,
          layout: :page_layout,
          locals: {
            context: AdminUI::Context.new(request.path),
            table: UC3Query::QueryClient.client.query(request.path, request.params)
          }
      end

      app.get '/ops/storage/db/**' do
        erb :table,
          layout: :page_layout,
          locals: {
            context: AdminUI::Context.new(request.path),
            table: UC3Query::QueryClient.client.query(request.path, request.params)
          }
      end

      app.post '/search' do
        term = URI.encode_www_form_component(params[:search])
        case params[:search_type]
        when 'inv_object_id'
          redirect "/queries/repository/object?inv_object_id=#{term}"
        when 'ark'
          redirect "/queries/repository/object-ark?ark=#{term}"
        when 'localid'
          redirect "/queries/repository/objects-localid?localid=#{term}"
        when 'erc_who'
          redirect "/queries/repository/objects-erc-who?term=#{term}"
        when 'erc_what'
          redirect "/queries/repository/objects-erc-what?term=#{term}"
        when 'erc_when'
          redirect "/queries/repository/objects-erc-when?term=#{term}"
        when 'filename'
          redirect "/queries/repository/objects-by-filename?term=#{term}"
        when 'container'
          redirect "/queries/repository/objects-by-container?term=#{term}"
        end
      end
    end
  end
  register UC3QueryRoutes
end
