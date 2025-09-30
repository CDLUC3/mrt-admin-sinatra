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

      app.get '/ops/storage/manifest' do
        url = "#{store_host}/manifest/#{request.params['node_number']}/#{CGI.escape(request.params['ark'])}"
        puts "URL: #{url}"
        get_url(url, ctype: :xml)
      end

      app.get '/ops/storage/manifest' do
        get_url(manifest_url(request.params), ctype: :xml)
      end

      app.get '/ops/storage/manifest-yaml' do
        data = get_url_body(manifest_url(request.params))
        content_type :yaml
        ManifestToYaml.new.load_xml(data)
      end

      app.get '/ops/storage/ingest-checkm' do
        nodenum = request.params['node_number']
        ark = request.params['ark']
        ver = request.params['version_number']
        url = "#{store_host}/ingestlink/#{nodenum}/#{CGI.escape(ark)}/#{ver}"
        puts "URL: #{url}"
        get_url(url, ctype: :text)
      end
    end

    def manifest_url(params)
      "#{store_host}/manifest/#{params['node_number']}/#{CGI.escape(params['ark'])}"
    end

    def stack_init
      UC3::FileSystemClient.client.cleanup_ingest_folders
      resp = []
      r = post_url("#{inventory_host}/admin/init")
      begin
        resp << ::JSON.parse(r)
      rescue StandardError => e
        resp << { action: 'Inventory Init', error: e.to_s }
      end
      collections_init.each do |r|
        resp << r
      end

      qc = UC3Query::QueryClient.client
      if !qc.nil? && qc.enabled
        begin
          sql = %(
            select * from inv.inv_nodes
          )
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
            resp << { action: 'Add test storage nodes', result: 'success' }
          else
            resp << { action: 'Add test storage nodes', result: 'skipped - already exists' }
          end

          sql = %(
            select * from billing.daily_node_counts
          )
          if qc.run_sql(sql).empty?
            qc.run_sql(%(
              insert into billing.daily_node_counts(
                as_of_date,
                inv_node_id,
                number,
                object_count,
                object_count_primary,
                object_count_secondary,
                file_count,
                billable_size
              )
              select
                date(now()), id, number, 1, 0, 0, 0, 0
              from inv.inv_nodes;
            ))
            resp << { action: 'Add test storage node counts', result: 'success' }
          else
            resp << { action: 'Add test storage node counts', result: 'skipped - already exists' }
          end
        rescue StandardError => e
          resp << { action: 'Add test storage node and node counts', error: e.to_s }
        end
      end
      resp
    end

    def collections_init
      resp = []
      [
        { ark: 'ark:/13030/m5rn35s8', name: 'Merritt Demo', mnemonic: 'merritt_demo', public: true },
        { ark: 'ark:/13030/m5qv8jks', name: 'cdl_dryaddev', mnemonic: 'cdl_dryaddev', public: true },
        { ark: 'ark:/13030/m5154f09', name: 'escholarship', mnemonic: 'escholarship', public: true },
        { ark: 'ark:/13030/99999999', name: 'Terry Test', mnemonic: 'terry_test', public: true }
      ].each do |c|
        r = UC3S3::ConfigObjectsClient.client.add_collection(
          c[:ark], c[:name], c[:mnemonic], public: c.fetch(:public, false)
        )
        begin
          resp << ::JSON.parse(r)
        rescue StandardError => e
          resp << { action: "Create Collection #{c[:name]}", error: e.to_s }
        end
      end
      resp
    end

    def get_url_body(url)
      uri = URI.parse(url)
      response = Net::HTTP.get_response(uri)
      response.body
    end

    def get_url(url, ctype: :json)
      uri = URI.parse(url)
      response = Net::HTTP.get_response(uri)
      data = response.body
      content_type ctype
      data
    rescue StandardError => e
      content_type :json
      { uri: uri, error: e.to_s }.to_json
    end

    def post_url_body(url, body: nil, user: nil, password: nil)
      puts "URI: #{url}, body: #{body}, user: #{user}, password: #{'****' if password}"
      uri = URI.parse(url)
      req = Net::HTTP::Post.new(uri)
      if user && password
        req.basic_auth(user, password)
        # token = Base64.strict_encode64("#{user}:#{password}")
        # req['Authorization'] = "Basic #{token}"
      end
      req['Content-Type'] = 'text/plain; charset=UTF-8'
      req['Accept'] = 'text/plain'

      req.body = body

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
        http.request(req)
      end
      response.body
    end

    def post_url(url, body: nil, user: nil, password: nil)
      json = post_url_body(url, body: body, user: user, password: password)
      content_type :json
      json
    rescue StandardError => e
      content_type :json
      { uri: uri, error: e.to_s }.to_json
    end

    def post_url_multipart(url, params)
      puts "POST #{url} with #{params.inspect}"
      uri = URI.parse(url)
      req = Net::HTTP::Post::Multipart.new(uri, params)
      response = Net::HTTP.start(uri.hostname, uri.port) do |http|
        http.request(req)
      end
      puts "Response: #{response.inspect}"
      response.body
    end
  end

  register UC3ServicesRoutes
end
