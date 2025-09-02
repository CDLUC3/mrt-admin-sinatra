# frozen_string_literal: true

require 'sinatra/base'
require 'net/http'
require 'net/http/post/multipart'
require_relative '../ui/context'

# custom sinatra routes
module Sinatra
  # client specific routes
  module UC3ServicesRoutes
    MERRITT_ADMIN_OWNER = 'ark:/13030/j2rn30xp'
    TEST_SLA = 'ark:/13030/77777777'

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
        post_url("#{inventory_host}/admin/init")
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
        content_type :json
        stack_init.to_json
      end

      app.post '/collections-init' do
        content_type :json
        collections_init.to_json
      end
    end

    def add_collection(ark, name, mnemonic, public: false)
      vis = public ? 'public' : 'private'
      post_url_multipart(
        "#{inventory_host}/admin/collection/#{vis}",
        { adminid: ark, name: name, mnemonic: mnemonic }
      )
    end

    def add_owner(ark, name, sla_ark)
      post_url_multipart(
        "#{inventory_host}/admin/owner",
        { adminid: ark, name: name, slaid: sla_ark }
      )
    end

    def add_sla(ark, name, mnemonic)
      post_url_multipart(
        "#{inventory_host}/admin/sla",
        { adminid: ark, name: name, mnemonic: mnemonic }
      )
    end

    def stack_init
      UC3::FileSystemClient.client.cleanup_ingest_folders
      resp = []
      r = post_url("#{inventory_host}/admin/init")
      begin
        resp << ::JSON.parse(r)
      rescue StandardError => e
        resp << { action: "Inventory Init", error: e.to_s }
      end
      collections_init.each do |r|
        resp << r
      end
      r = post_url("#{replic_host}/service/start?t=json")
      begin
        resp << ::JSON.parse(r)
      rescue StandardError => e
        resp << { action: "Replic Init", error: e.to_s }
      end
      r = post_url("#{audit_host}/service/start?t=json")
      begin
        resp << ::JSON.parse(r)
      rescue StandardError => e
        resp << { action: "Audit Init", error: e.to_s }
      end

      qc = UC3Query::QueryClient.client
      if !qc.nil? && qc.enabled
        begin
          sql = %{
            select * from inv.inv_nodes
          }
          if qc.run_sql(sql).empty?
            qc.run_sql(%(
              insert into inv.inv_nodes(
                number,
                media_type,
                media_connectivity,
                access_mode,
                access_protocol,
                node_form,
                node_protocol,
                logical_volume,
                external_provider,
                verify_on_read,
                verify_on_write,
                base_url
              )
              select
                7777,
                'magnetic-disk',
                'cloud',
                'on-line',
                's3',
                'physical',
                'http',
                'yaml:7777',
                'nodeio',
                1,
                1,
                'http://store:8080/store'
              union
              select
                8888,
                'magnetic-disk',
                'cloud',
                'on-line',
                's3',
                'physical',
                'http',
                'yaml:8888',
                'nodeio',
                1,
                1,
                'http://store:8080/store'
            ))
            resp << { action: "Add test storage nodes", result: "success" }
          else
            resp << { action: "Add test storage nodes", result: "skipped - already exists" }
          end

          sql = %{
            select * from billing.daily_node_counts
          }
          if qc.run_sql(sql).empty?
            qc.run_sql(%(
              insert into billing.daily_node_counts(
                as_of_date,inv_node_id, number, object_count, object_count_primary, object_count_secondary, file_count, billable_size
              )
              select 
                date(now()), id, number, 1, 0, 0, 0, 0
              from inv.inv_nodes;
            ))
            resp << { action: "Add test storage node counts", result: "success" }
          else
            resp << { action: "Add test storage node counts", result: "skipped - already exists" }
          end
          qc.run_sql(%{update inv.inv_objects set aggregate_role='MRT-service-level-agreement' where ark='ark:/13030/j2h41690'})
          resp << { action: "Temp fix complete" }
        rescue StandardError => e
          resp << { action: "Add test storage node and node counts", error: e.to_s }
        end
      end
      resp
    end

    def collections_init
      resp = []
      [
        # {ark: TEST_SLA, name: 'Test SLA', mnemonic: 'test_sla' }
      ].each do |c|
        r = add_sla(c[:ark], c[:name], c[:mnemonic])
        begin
          resp << ::JSON.parse(r)
        rescue StandardError => e
          resp << { action: "Create SLA #{c[:name]}", error: e.to_s }
        end
      end
      [
        # { ark: 'ark:/13030/88888888', name: 'Test Owner', sla_ark: MERRITT_ADMIN_OWNER }
      ].each do |own|
        r = add_owner(own[:ark], own[:name], own[:sla_ark])
        begin
          resp << ::JSON.parse(r)
        rescue StandardError => e
          resp << { action: "Create Owner #{own[:name]}", error: e.to_s }
        end
      end

      [
        { ark: 'ark:/13030/m5rn35s8', name: 'Merritt Demo', mnemonic: 'merritt_demo', public: true },
        { ark: 'ark:/13030/m5qv8jks', name: 'cdl_dryaddev', mnemonic: 'cdl_dryaddev', public: true },
        { ark: 'ark:/13030/m5154f09', name: 'escholarship', mnemonic: 'escholarship', public: true },
        { ark: 'ark:/13030/99999999', name: 'Terry Test', mnemonic: 'terry_test', public: true }
      ].each do |c|
        r = add_collection(c[:ark], c[:name], c[:mnemonic], public: c.fetch(:public, false))
        begin
          resp << ::JSON.parse(r)
        rescue StandardError => e
          resp << { action: "Create Collection #{c[:name]}", error: e.to_s }
        end
      end
      resp
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

    def post_url_multipart(url, params)
      uri = URI.parse(url)
      req = Net::HTTP::Post::Multipart.new(uri, params)
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
