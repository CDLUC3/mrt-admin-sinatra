# frozen_string_literal: true

require 'sinatra/base'
require 'sinatra/contrib'
require 'uri'
require_relative '../client/query/query'
require_relative '../client/query/query_resolvers'
require_relative '../ui/context'

# custom sinatra routes
module Sinatra
  # client specific routes
  module UC3QueryRoutes
    def self.registered(app)
      app.get '/queries/repository' do
        adminui_show_none(
          AdminUI::Context.new(request.path)
        )
      end

      app.get '/queries/consistency' do
        adminui_show_none(
          AdminUI::Context.new(request.path)
        )
      end

      [
        '/queries/repository/object*',
        '/queries/*/objlist',
        '/ops/*/objlist',
        '/queries/recent/objects'
      ].each do |path|
        app.get path do
          erb :tables,
            layout: :page_layout,
            locals: {
              context: AdminUI::Context.new(request.path),
              table: UC3Query::QueryClient.client.query(
                request.path,
                request.params,
                resolver: UC3Query::QueryResolvers.method(:obj_info_resolver),
                dispcols: %w[
                  inv_object_id ark actions version_number mnemonics metadata local_ids created billable_size
                  file_count
                ]
              ),
              aux_tables: [
                UC3Query::QueryClient.client.query(
                  request.path,
                  request.params,
                  sqlsym: :repl_sql,
                  resolver: UC3Query::QueryResolvers.method(:obj_node_resolver),
                  dispcols: %w[role actions description created replicated unverified last_verified version_number]
                ),
                UC3Query::QueryClient.client.query(
                  request.path,
                  request.params,
                  sqlsym: :files_sql
                )
              ]
            }
        end
      end

      app.post '/queries/update-billing' do
        UC3Query::QueryClient.client.update_billing
        redirect '/queries/repository/collections/bytes'
      end

      app.get '/queries/recent/ingests/today' do
        redirect "/queries/recent/ingests?date=#{Date.today.strftime('%Y-%m-%d')}"
      end

      app.get '/queries/content/mnemonic/*' do
        if request.params.key?('mnemonic')
          result = UC3Query::QueryClient.client.query(request.path, request.params)

          if result.is_a?(AdminUI::FilterTable)
            adminui_show_table(
              AdminUI::Context.new(request.path),
              result
            )
          else
            redirect '/saved-reports/list'
          end
        else
          adminui_show_table(
            AdminUI::Context.new(request.path),
            UC3Query::QueryClient.client.query('/queries/collections', request.params)
          )
        end
      end

      app.get '/queries/**' do
        request.params[:term] = URI.decode_www_form_component(request.params[:term]) if request.params.key?(:term)

        adminui_show_table(
          AdminUI::Context.new(request.path),
          UC3Query::QueryClient.client.query(request.path, request.params)
        )
      end

      app.get '/ops/db-queue/audit/active-batches' do
        adminui_show_table(
          AdminUI::Context.new(request.path),
          UC3Query::QueryClient.client.query(request.path, request.params),
          erb: :audit_batches_table,
          locals: {
            hours: [24, 2, 1]
          }
        )
      end

      app.post '/queries-update/storage-maints/batch-update-status' do
        request.params.fetch('idlist', '').split(',') do |id|
          cparams = {}
          cparams['maint_id'] = id
          cparams['status'] = request.params['status']
          UC3Query::QueryClient.client.query_update(
            '/queries-update/storage-maints/update-status', cparams
          )
        end
        redirect request.referrer
      end

      app.post '/queries-update/audit/active-batches-clear' do
        UC3Query::QueryClient.client.query_update(request.path, request.params)
        redirect request.referrer
      end

      app.post '/queries-update/storage-nodes/add' do
        res = UC3Query::QueryClient.client.query_update(request.path, request.params)
        puts res.to_json
        if res.fetch(:status, 'FAIL') == 'OK'
          res = UC3Query::QueryClient.client.query_update('/queries-update/storage-nodes/trigger-replication',
            request.params)
          puts res.to_json
        end
        redirect request.referrer
      end

      app.post '/queries-update/**' do
        content_type :json
        UC3Query::QueryClient.client.query_update(request.path, request.params).to_json
      end

      app.get '/ops/collections/storage-node-config/**' do
        adminui_show_table(
          AdminUI::Context.new(request.path),
          UC3Query::QueryClient.client.query(
            '/ops/collections/storage-node-config/collection',
            request.params,
            resolver: UC3Query::QueryResolvers.method(:single_collection_nodes_resolver),
            dispcols: %w[role node_number description access_mode count total pct_complete actions]
          ),
          erb: :coll_node_table,
          locals: {
            nodes: get_nodes,
            inv_collection_id: request.params.fetch('inv_collection_id', '-1'),
            mnemonic: request.params.fetch('mnemonic', 'coll'),
            primary: request.params.fetch('primary', '-1')
          }
        )
      end

      app.get '/ops/collections/storage-node-config' do
        adminui_show_table(
          AdminUI::Context.new(request.path),
          UC3Query::QueryClient.client.query(
            request.path,
            request.params,
            resolver: UC3Query::QueryResolvers.method(:collections_nodes_resolver)
          )
        )
      end

      app.get '/ops/storage/scans' do
        adminui_show_table(
          AdminUI::Context.new(request.path),
          UC3Query::QueryClient.client.query(
            request.path,
            request.params,
            resolver: UC3Query::QueryResolvers.method(:storage_scan_resolver),
            dispcols: %w[
              nodedesc scan_status created num_review num_deletes num_holds num_maints
              keys_processed percent_complete actions
]
          ),
          erb: :storage_scan_table
        )
      end

      app.get '/ops/storage/scans/review*' do
        adminui_show_table(
          AdminUI::Context.new(request.path),
          UC3Query::QueryClient.client.query(
            request.path,
            request.params,
            resolver: UC3Query::QueryResolvers.method(:storage_scan_review_resolver),
            dispcols: %w[
              maint_id s3key_annotated maint_type maint_status note actions
]
          ),
          erb: :storage_scan_review_table,
          locals: {
            status: request.params.fetch('status', ''),
            node_number: request.params.fetch('node_number', 0),
            storage_mgt_disabled: UC3Query::QueryResolvers.storage_mgt_disabled?
          }
        )
      end

      app.get '/ops/storage/scans/csvfile' do
        adminui_show_table(
          AdminUI::Context.new(request.path),
          UC3Query::QueryClient.client.query(
            request.path,
            request.params,
            resolver: UC3Query::QueryResolvers.method(:storage_scan_csv_resolver),
            dispcols: %w[
              node_number maint_id key_ark key_ver key_folder key_file maint_type
              file_created size maint_status note new_status new_note
]
          )
        )
      end

      app.get '/ops/db-queue/audit/counts-by-state' do
        adminui_show_table(
          AdminUI::Context.new(request.path),
          UC3Query::QueryClient.client.query(
            request.path,
            request.params,
            resolver: UC3Query::QueryResolvers.method(:audit_status_resolver)
          )
        )
      end

      [
        '/ops/db-queue/**',
        '/ops/storage/scans/**'
      ].each do |path|
        app.get path do
          adminui_show_table(
            AdminUI::Context.new(request.path),
            UC3Query::QueryClient.client.query(request.path, request.params)
          )
        end
      end

      # This should be a post request, but it is easier to automate as a consistency check if it is done as a get
      # This is not yet tested on real data
      app.get '/ops/db-queue-update/audit/reset-new-ucb-content' do
        adminui_show_table(
          AdminUI::Context.new(request.path),
          UC3Query::QueryClient.client.reset_new_ucb_content(request.path, request.params)
        )
      end

      app.get '/ops/collections/db/**' do
        adminui_show_table(
          AdminUI::Context.new(request.path),
          UC3Query::QueryClient.client.query(request.path, request.params)
        )
      end

      app.get '/ops/storage/db/**' do
        adminui_show_table(
          AdminUI::Context.new(request.path),
          UC3Query::QueryClient.client.query(request.path, request.params)
        )
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
