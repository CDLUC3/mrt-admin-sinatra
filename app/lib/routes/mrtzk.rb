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
        adminui_show_table(
          AdminUI::Context.new(request.path),
          UC3Queue::ZKClient.client.dump_nodes(request.path, request.params)
        )
      end

      app.get '/ops/zk/nodes/orphan' do
        request.params['zkpath'] ||= '/'
        request.params['mode'] ||= 'test'
        adminui_show_table(
          AdminUI::Context.new(request.path),
          UC3Queue::ZKClient.client.dump_nodes(request.path, request.params)
        )
      end

      app.post '/ops/zk/nodes/force-failure/states' do
        zk = UC3Queue::ZKClient.client
        zk.create_node('/batches/bid99998')
        zk.create_node('/batches/bid99998/states')
        zk.create_node('/batches/bid99998/submission', data: { foo: 'bar' }.to_json)

        redirect '/ops/zk/nodes/orphan'
      end

      app.post '/ops/zk/nodes/force-failure/duplicate-batch-states' do
        zk = UC3Queue::ZKClient.client
        zk.create_node('/jobs/jid77777')
        zk.create_node('/jobs/jid77777/bid', data: 'bid99999')
        zk.create_node('/jobs/jid77777/status', data: { status: 'processing' }.to_json)
        zk.create_node('/jobs/states/processing/00-jid77777')
        zk.create_node('/batches/bid99999')

        zk.create_node('/batches/bid99999/states')
        zk.create_node('/batches/bid99999/states/batch-processing/jid77777')
        zk.create_node('/batches/bid99999/states/batch-failed/jid77777')

        redirect '/ops/zk/nodes/orphan'
      end

      app.post '/ops/zk/nodes/force-failure/duplicate-job-states' do
        zk = UC3Queue::ZKClient.client
        zk.create_node('/jobs/jid77776')
        zk.create_node('/jobs/jid77776/status', data: { status: 'processing' }.to_json)
        zk.create_node('/jobs/states/processing/00-jid77776')
        zk.create_node('/jobs/states/estimating/00-jid77776')

        redirect '/ops/zk/nodes/orphan'
      end

      app.post '/ops/zk/nodes/force-failure/lock' do
        zk = UC3Queue::ZKClient.client
        zk.create_node('/batches/bid99997')
        zk.create_node('/batches/bid99997/lock')

        redirect '/ops/zk/nodes/orphan'
      end

      app.post '/ops/zk/nodes/delete' do
        f = request.body.read
        if f.empty?
          content_type :json
          { message: 'No path specified' }.to_json
        else
          zk = UC3Queue::ZKClient.client
          zk.delete_node(f)
          content_type :json
          { message: "#{f} deleted" }.to_json
        end
      rescue StandardError => e
        content_type :json
        { message: "ERROR: #{e.class}: #{e.message}" }.to_json
      end

      app.get '/ops/zk/ingest/batches' do
        adminui_show_table(
          AdminUI::Context.new(request.path),
          UC3Queue::ZKClient.client.batches(request.path)
        )
      end

      [
        '/ops/zk/ingest/jobs-by-collection',
        '/ops/zk/ingest/jobs-by-collection/filtered',
        '/ops/zk/ingest/jobs-by-collection-and-batch/filtered'
      ].each do |path|
        app.get path do
          adminui_show_table(
            AdminUI::Context.new(request.path),
            UC3Queue::ZKClient.client.jobs_by_collection(request.path, request.params),
            erb: :jobs_table
          )
        end
      end

      app.get '/ops/zk/ingest/jobs-by-collection-and-batch' do
        adminui_show_table(
          AdminUI::Context.new(request.path),
          UC3Queue::ZKClient.client.jobs_by_collection_and_batch(request.path, request.params)
        )
      end

      app.post '/ops/zk/ingest/pause' do
        UC3Queue::ZKClient.client.pause_ingest
        redirect '/ops/zk/nodes/node-names?zkpath=/locks&mode=node'
      end

      app.post '/ops/zk/ingest/unpause' do
        UC3Queue::ZKClient.client.unpause_ingest
        redirect '/ops/zk/nodes/node-names?zkpath=/locks&mode=node'
      end

      app.post '/ops/zk/ingest/cleanup-queue' do
        UC3Queue::ZKClient.client.cleanup_ingest_queue
        redirect '/ops/zk/ingest/batches'
      end

      app.post '/ops/zk/access/pause-small' do
        UC3Queue::ZKClient.client.pause_access_small
        redirect '/ops/zk/nodes/node-names?zkpath=/locks&mode=node'
      end

      app.post '/ops/zk/access/unpause-small' do
        UC3Queue::ZKClient.client.unpause_access_small
        redirect '/ops/zk/nodes/node-names?zkpath=/locks&mode=node'
      end

      app.post '/ops/zk/access/pause-large' do
        UC3Queue::ZKClient.client.pause_access_large
        redirect '/ops/zk/nodes/node-names?zkpath=/locks&mode=node'
      end

      app.post '/ops/zk/access/unpause-large' do
        UC3Queue::ZKClient.client.unpause_access_large
        redirect '/ops/zk/nodes/node-names?zkpath=/locks&mode=node'
      end

      app.post '/ops/zk/access/cleanup-queue' do
        UC3Queue::ZKClient.client.cleanup_access_queue
        redirect '/ops/zk/access/jobs'
      end

      app.get '/ops/zk/access/jobs' do
        adminui_show_table(
          AdminUI::Context.new(request.path),
          UC3Queue::ZKClient.client.assembly_requests(request.path)
        )
      end

      app.post '/ops/zk/access/delete/*/*' do
        qn = params[:splat][0]
        id = params[:splat][1]
        path = "/#{qn}/#{id}"
        begin
          UC3Queue::ZKClient.client.delete_access(qn, id)
          content_type :json
          { message: "#{path} marked for deletion" }.to_json
        rescue StandardError => e
          content_type :json
          { path: path, message: "ERROR: #{e.class}: #{e.message}" }.to_json
        end
      end

      app.post '/ops/zk/ingest/job/delete/*' do
        id = params[:splat][0]
        begin
          UC3Queue::ZKClient.client.delete_ingest_job(id)
          content_type :json
          { message: "#{id} marked for deletion" }.to_json
        rescue StandardError => e
          content_type :json
          { job: id, message: "ERROR: #{e.class}: #{e.message}" }.to_json
        end
      end

      app.post '/ops/zk/ingest/job/requeue/*' do
        id = params[:splat][0]
        begin
          UC3Queue::ZKClient.client.requeue_ingest_job(id)
          content_type :json
          { message: "#{id} requeued" }.to_json
        rescue StandardError => e
          content_type :json
          { job: id, message: "ERROR: #{e.class}: #{e.message}" }.to_json
        end
      end

      app.post '/ops/zk/ingest/job/hold/*' do
        id = params[:splat][0]
        begin
          UC3Queue::ZKClient.client.hold_ingest_job(id)
          content_type :json
          { message: "#{id} held" }.to_json
        rescue StandardError => e
          content_type :json
          { job: id, message: "ERROR: #{e.class}: #{e.message}" }.to_json
        end
      end

      app.post '/ops/zk/ingest/job/release/*' do
        id = params[:splat][0]
        begin
          UC3Queue::ZKClient.client.release_ingest_job(id)
          content_type :json
          { message: "#{id} released" }.to_json
        rescue StandardError => e
          content_type :json
          { job: id, message: "ERROR: #{e.class}: #{e.message}" }.to_json
        end
      end

      app.post '/ops/zk/ingest/batch/delete/*' do
        id = params[:splat][0]
        begin
          UC3Queue::ZKClient.client.delete_ingest_batch(id)
          content_type :json
          { message: "#{id} marked for deletion" }.to_json
        rescue StandardError => e
          content_type :json
          { batch: id, message: "ERROR: #{e.class}: #{e.message}" }.to_json
        end
      end

      app.post '/ops/zk/ingest/batch/update-reporting/*' do
        id = params[:splat][0]
        begin
          UC3Queue::ZKClient.client.update_reporting_ingest_batch(id)
          content_type :json
          { message: "#{id} marked for update reporting" }.to_json
        rescue StandardError => e
          content_type :json
          { batch: id, message: "ERROR: #{e.class}: #{e.message}" }.to_json
        end
      end

      app.post '/ops/zk/access/requeue/*/*' do
        qn = params[:splat][0]
        id = params[:splat][1]
        path = "/#{qn}/#{id}"
        begin
          UC3Queue::ZKClient.client.requeue_access(qn, id)
          content_type :json
          { path: path, message: "Requeued #{path}" }.to_json
        rescue StandardError => e
          content_type :json
          { path: path, message: "ERROR: #{e.class}: #{e.message}" }.to_json
        end
      end

      app.post '/ops/zk/access/fake' do
        UC3Queue::ZKClient.client.fake_access
        redirect '/ops/zk/access/jobs'
      end

      app.get '/ops/ingest-folders/list' do
        adminui_show_table(
          AdminUI::Context.new(request.path),
          UC3::FileSystemClient.client.ingest_folders(request.path, request.params)
        )
      end

      app.post '/ops/ingest-folders/cleanup' do
        UC3::FileSystemClient.client.cleanup_ingest_folders
        redirect '/ops/ingest-folders/list'
      end

      app.post '/ops/ingest-folders/delete' do
        f = request.body.read
        if f.empty?
          content_type :json
          { message: 'No file specified' }.to_json
        else
          File.delete("#{UC3::FileSystemClient::DIR}/#{f}")
          content_type :json
          { message: "#{f} deleted" }.to_json
        end
      rescue StandardError => e
        content_type :json
        { message: "ERROR: #{e.class}: #{e.message}" }.to_json
      end

      app.post '/ops/ingest-folders/force-failure/estimating' do
        File.new('/tdr/ingest/queue/Estimate_FAIL', 'w')
        redirect '/ops/ingest-folders/list'
      end

      app.post '/ops/ingest-folders/force-failure/provisioning' do
        File.new('/tdr/ingest/queue/Provision_FAIL', 'w')
        redirect '/ops/ingest-folders/list'
      end

      app.post '/ops/ingest-folders/force-failure/download' do
        File.new('/tdr/ingest/queue/Download_FAIL', 'w')
        redirect '/ops/ingest-folders/list'
      end

      app.post '/ops/ingest-folders/force-failure/processing' do
        File.new('/tdr/ingest/queue/Process_FAIL', 'w')
        redirect '/ops/ingest-folders/list'
      end

      app.post '/ops/ingest-folders/force-failure/notify' do
        File.new('/tdr/ingest/queue/Notify_FAIL', 'w')
        redirect '/ops/ingest-folders/list'
      end

      app.post '/ops/zk/snapshot' do
        UC3Queue::ZKClient.client.save_snapshot
        redirect '/ops/ingest-folders/list?path=/zk-snapshots'
      end

      app.post '/ops/zk/restore' do
        UC3Queue::ZKClient.client.restore_from_snapshot
        redirect '/ops/zk/nodes/node-names?zkpath=/&mode=node'
      end

      app.get '/ops/zk/stat' do
        content_type :json
        UC3Queue::ZKClient.client.zk_stat.to_json
      end

      app.post '/ops/zk/collection/lock' do
        UC3Queue::ZKClient.client.lock_collection(request.params['mnemonic'])
        content_type :json
        { message: "Collection #{request.params['mnemonic']} Locked" }.to_json
      end

      app.post '/ops/zk/collection/unlock' do
        UC3Queue::ZKClient.client.unlock_collection(request.params['mnemonic'])
        content_type :json
        { message: "Collection #{request.params['mnemonic']} Unlocked" }.to_json
      end

      app.get '/ops/zk/ingest/maintenance' do
        erb :zk_ingest_maintenance, layout: :page_layout, locals: {
          context: AdminUI::Context.new(request.path)
        }
      end

      app.get '/ops/zk/access/maintenance' do
        erb :zk_access_maintenance, layout: :page_layout, locals: {
          context: AdminUI::Context.new(request.path)
        }
      end

      app.get '/ops/zk/maintenance' do
        erb :zk_maintenance, layout: :page_layout, locals: {
          context: AdminUI::Context.new(request.path)
        }
      end
    end
  end

  register UC3ZKRoutes
end
