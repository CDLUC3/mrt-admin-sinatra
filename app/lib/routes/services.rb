# frozen_string_literal: true

require 'sinatra/base'
require 'net/http'
require 'net/http/post/multipart'
require 'benchmark'
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
      "http://#{ENV.fetch('SVC_ACCESS', 'store:8080/store')}"
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

      app.post '/ops/inventory/rebuild' do
        nodenum = request.params.fetch('node_number', '')
        ark = request.params.fetch('ark', '')

        if nodenum.empty? || ark.empty?
          return adminui_show_none(
            AdminUI::Context.new(request.path, request.params, show_formats: false)
          )
        end

        data = {
          url: manifest_url(nodenum, ark),
          responseForm: 'json'
        }

        deleteurl = "#{inventory_host}/object/#{CGI.escape(ark)}"
        resp = delete_url_resp(deleteurl)
        if resp.code.to_i == 200
          addurl = "#{inventory_host}/add"
          resp = post_url_multipart(addurl, data)
          if resp.code.to_i == 200
            url = "/queries/repository/object-ark?ark=#{CGI.escape(ark)}"
            {
              message: "Sucessfully re-added #{ark} to inventory",
              redirect: url,
              modal: true
            }.to_json
          else
            content_type :json
            { uri: addurl, message: "ERROR re-adding object: #{resp.code}" }.to_json
          end
        else
          content_type :json
          { uri: deleteurl, message: "ERROR deleting object: #{resp.code}" }.to_json
        end
      rescue StandardError => e
        content_type :json
        { uri: deleteurl, message: "Exception while rebuilding inventory: #{e}" }.to_json
      end

      app.post '/ops/storage-nodes/remove-obsolete' do
        arks = UC3Query::QueryClient.client.run_query(request.path, request.params)
        nodenumber = request.params.fetch('node_number', -1)
        success = 0
        fail = 0
        arks.each do |row|
          ark = row.fetch('ark', '')
          next if ark.empty?

          deleteurl = "#{replic_host}/delete/#{nodenumber}/#{CGI.escape(ark)}"
          puts deleteurl
          dresp = delete_url_resp(deleteurl)
          if dresp.code.to_i == 200
            success += 1
          else
            fail += 1
          end
        end

        content_type :json
        { message: "Deleted objects: #{success}; failed: #{fail}" }.to_json
      end

      app.get '/ops/storage/manifest' do
        nodenum = request.params.fetch('node_number', '')
        ark = request.params.fetch('ark', '')

        if nodenum.empty? || ark.empty?
          return adminui_show_none(
            AdminUI::Context.new(request.path, request.params, show_formats: false)
          )
        end

        url = "#{store_host}/manifest/#{nodenum}/#{CGI.escape(ark)}"
        get_url(url, ctype: :xml)
      end

      app.get '/ops/storage/manifest-yaml' do
        nodenum = request.params.fetch('node_number', '')
        ark = request.params.fetch('ark', '')

        if nodenum.empty? || ark.empty?
          return adminui_show_none(
            AdminUI::Context.new(request.path, request.params, show_formats: false)
          )
        end

        data = get_url_body(manifest_url(nodenum, ark))
        content_type :yaml
        ManifestToYaml.new.load_xml(data)
      end

      app.get '/ops/storage/ingest-checkm' do
        nodenum = request.params.fetch('node_number', '')
        ark = request.params.fetch('ark', '')
        ver = request.params.fetch('version_number', '')

        if nodenum.empty? || ark.empty? || ver.empty?
          return adminui_show_none(
            AdminUI::Context.new(request.path, request.params, show_formats: false)
          )
        end

        url = "#{store_host}/ingestlink/#{nodenum}/#{CGI.escape(ark)}/#{ver}?presign=true"
        get_url(url, ctype: :text)
      end

      app.post '/ops/storage/scans/cancel-all-scans' do
        post_url("#{replic_host}/scan/allow/false?t=json")
      end

      app.post '/ops/storage/scans/allow-all' do
        post_url("#{replic_host}/scan/allow/true?t=json")
      end

      app.post '/ops/storage/scans/start' do
        node = request.params.fetch('node_number', 'na')
        keylist = request.params.fetch('keylist', '')
        url = "#{replic_host}/scan/start/#{node}?t=json"
        url += "&keylist=#{keylist}" unless keylist.empty?
        post_url_message(url, message: 'Scan Started')
      end

      app.post '/ops/storage/scans/resume' do
        post_url_message("#{replic_host}/scan/restart/#{request.params.fetch('inv_scan_id', 'na')}?t=json",
          message: 'Scan Restarted')
      end

      app.post '/ops/storage/scans/cancel' do
        post_url_message("#{replic_host}/scan/cancel/#{request.params.fetch('inv_scan_id', 'na')}?t=json",
          message: 'Scan Cancelled')
      end

      app.post '/ops/storage/scans/delete' do
        delete_url_message("#{replic_host}/scandelete/#{request.params.fetch('maint_id', 0)}?t=json",
          message: 'Scan Item Removed from Cloud Storage')
      end

      app.post '/ops/storage/scans/batch-delete' do
        delete_url_message("#{replic_host}/scandelete-list/#{request.params.fetch('node_number', 0)}?t=json",
          message: 'Scan Delete Batch Initiated')
      end

      app.post '/ops/storage/scans/applycsv' do
        count = 0
        errors = 0
        CSV.parse(request.body.read).each_with_index do |row, i|
          next if i.zero?

          row[11] = '' if row[11].nil?
          row[12] = '' if row[12].nil?
          next if row[11].empty?
          next if row[9] == row[11] && row[10] == row[12]

          params = {}
          params['maint_status'] = row[11]
          params['note'] = row[12]
          params['node_number'] = row[0].to_i
          params['maint_id'] = row[1].to_i
          res = UC3Query::QueryClient.client.query_update(
            '/queries-update/storage-maints/apply-review-change',
            params
          )
          if res.fetch(:status, '') == 'OK'
            puts params
            count += 1
          else
            puts res
            errors += 1
          end
        end
        content_type :json
        { message: "Changes applied #{count}; Errors: #{errors}" }.to_json
      end

      app.get '/ops/storage/storage-config' do
        rows = []
        defprofile = case UC3::UC3Client.stack_name
                     when UC3::UC3Client::ECS_EPHEMERAL
                       'minio-ephemeral'
                     when 'docker'
                       'minio-docker'
                     else
                       ''
                     end

        nodes = ::JSON.parse(get_url_body("#{store_host}/jsonstatus"))
        nodes.fetch('NodesStatus', []).each do |node|
          row = {
            node_number: node.fetch('node', ''),
            bucket: node.fetch('bucket', ''),
            description: node.fetch('description', ''),
            profile: defprofile
          }
          row[:profile] = 'sdsc' if row[:bucket] =~ /sdsc/
          row[:profile] = 'wasabi' if row[:bucket] =~ /wasabi/
          rows << row
        end

        rows << {
          bucket: ENV.fetch('S3CONFIG_BUCKET', ''),
          description: 'Configuration Bucket. AWS CodeBuild copies configuration data from GitHub into this bucket.',
          profile: defprofile
        }
        rows << {
          bucket: ENV.fetch('S3REPORT_BUCKET', ''),
          description: 'Reporting Bucket.' \
                       'The Merritt Admin Tool builds static reports into this bucket. ' \
                       'A lifecycle policy will expire content in this bucket.',
          profile: defprofile
        }
        rows << {
          bucket: ENV.fetch('S3WORKSPACE_BUCKET', ''),
          description: 'Versioned Workspace Bucket. Merritt Ingest and Storage ' \
                       'services will use this bucket for content that is actively being ingested. ' \
                       'A lifecycle policy will function like a recycle bin for content that has been deleted ' \
                       'from this bucket.',
          profile: defprofile
        }

        table = AdminUI::FilterTable.new(
          columns: [
            AdminUI::Column.new(:description, header: 'Description'),
            AdminUI::Column.new(:node_number, header: 'Node Number'),
            AdminUI::Column.new(:bucket, header: 'Bucket'),
            AdminUI::Column.new(:profile, header: 'Profile'),
            AdminUI::Column.new(:command, header: 'Command')
          ]
        )
        rows.each do |row|
          cmd = UC3::UC3Client.stack_name == 'docker' ? 'docker compose exec -it merrittdev /bin/bash' : "session #{UC3::UC3Client.cluster_name}/merrittdev"
          cmd += "\n"
          cmd += "\n/set-credentials.sh" if %w[sdsc wasabi].include?(row[:profile])
          cmd += "\naws s3#{" --profile #{row[:profile]}" unless row[:profile].empty?} ls s3://#{row[:bucket]}/"
          row[:command] = cmd unless row[:bucket].empty?
          table.add_row(
            AdminUI::Row.make_row(
              table.columns,
              row
            )
          )
        end
        adminui_show_table(
          AdminUI::Context.new(request.path, request.params),
          table
        )
      end

      app.get '/ops/storage/benchmark-fixity' do
        # Eventually this should open a page with a form to trigger the fixity check
        table = benchmark_fixity(request.params)
        adminui_show_table(
          AdminUI::Context.new(request.path, request.params),
          table
        )
      end

      app.post '/ops/storage/benchmark-fixity' do
        table = benchmark_fixity(request.params)
        adminui_show_table(
          AdminUI::Context.new(request.path, request.params),
          table
        )
      end

      app.post '/test/load/data' do
        test_data_dir = "#{UC3::FileSystemClient::DIR}/test-data"
        `mkdir -p #{test_data_dir}`
        sample_data = 'https://raw.githubusercontent.com/CDLUC3/mrt-doc/refs/heads/main/sampleFiles/'
        %w[merritt_demo cdl_dryaddev escholarship terry_test].each do |mnemonic|
          [
            { type: 'container-batch-manifest', file: 'sampleBatchOfContainers.checkm' },
            { type: 'object-manifest', file: 'sampleBatchOfFiles.checkm' },
            { type: 'batch-manifest', file: 'sampleBatchOfManifests.checkm' },
            { type: 'container', file: 'jazzbears.zip' },
            { type: 'file', file: 'bigHunt2.jpg' }
          ].each do |subm|
            file = "#{test_data_dir}/#{subm[:file]}"
            url = "#{sample_data}/#{subm[:file]}"
            `curl -L -o #{file} #{url} 2>/dev/null` unless File.exist?(file)
            load_test_file_to_merritt(file, subm[:type], mnemonic)
            sleep 5
          end
        end
        redirect '/ops/zk/ingest/jobs-by-collection'
      end
    end

    def benchmark_credentials(nodenum)
      arr = []
      ssm = ENV.fetch('MAIN_SSM_ROOT_PATH', '')

      prefix = "aws ssm get-parameter --name #{ssm}cloud/nodes"

      case nodenum
      when 9501, 9502, 9503
        unless ssm.empty?
          arr << %(export AWS_ACCESS_KEY_ID=)
          arr << %(export AWS_SECRET_ACCESS_KEY=)
          arr << %(AAIK=$(#{prefix}/sdsc-accessKey --with-decryption | jq -r .Parameter.Value))
          arr << %(ASAK=$(#{prefix}/sdsc-secretKey --with-decryption | jq -r .Parameter.Value))
          arr << %(export AWS_ACCESS_KEY_ID=$AAIK)
          arr << %(export AWS_SECRET_ACCESS_KEY=$ASAK)
        end
      when 2001, 2002, 2003
        unless ssm.empty?
          arr << %(export AWS_ACCESS_KEY_ID=)
          arr << %(export AWS_SECRET_ACCESS_KEY=)
          arr << %(AAIK=$(#{prefix}/wasabi-accessKey --with-decryption | jq -r .Parameter.Value))
          arr << %(ASAK=$(#{prefix}/wasabi-secretKey --with-decryption | jq -r .Parameter.Value))
          arr << %(export AWS_ACCESS_KEY_ID=$AAIK)
          arr << %(export AWS_SECRET_ACCESS_KEY=$ASAK)
        end
      when 7777, 8888
        unless ENV.fetch('S3ENDPOINT', '').empty?
          arr << %(export AWS_ACCESS_KEY_ID=)
          arr << %(export AWS_SECRET_ACCESS_KEY=)
          arr << %(export AWS_ACCESS_KEY_ID=minioadmin)
          arr << %(export AWS_SECRET_ACCESS_KEY=minioadmin)
        end
      end
      arr
    end

    def benchmark_path(nodenum, ark, version, pathname)
      case nodenum
      when 9501, 9502, 9503
        bucket = ENV.fetch('SDSC_BUCKET', '')
      when 2001, 2002, 2003
        bucket = ENV.fetch('WASABI_BUCKET', '')
      when 5001, 5003
        bucket = ENV.fetch('S3_BUCKET', '')
      when 7777
        bucket = ENV.fetch('BUCKET7777', '')
      when 8888
        bucket = ENV.fetch('BUCKET8888', '')
      else
        return ''
      end

      "s3://#{bucket}/#{ark}|#{version}|#{pathname}"
    end

    def benchmark_endpoint(nodenum)
      case nodenum
      when 9501, 9502, 9503
        ENV.fetch('SDSC_ENDPOINT', '')
      when 2001, 2002, 2003
        ENV.fetch('WASABI_ENDPOINT', '')
      when 7777, 8888
        ENV.fetch('S3ENDPOINT', '')
      else
        ''
      end
    end

    def benchmark_script(nodenum, ark, version, pathname)
      arr = []
      path = benchmark_path(nodenum, ark, version, pathname)

      return arr if path.empty?

      arr << ''
      arr << '```'
      benchmark_credentials(nodenum).each do |line|
        arr << line
      end

      endpoint = benchmark_endpoint(nodenum)
      endpoint_param = endpoint.empty? ? '' : "--endpoint-url #{endpoint}"
      region = ENV.fetch('S3REGION', '')
      region_param = " --region #{region}" unless region.empty?

      arr << %(time aws s3 #{region_param} #{endpoint_param} cp "#{path}" /dev/null)
      arr << '```'
      arr << ""
      arr
    end

    def benchmark_fixity(params)
      desc = []
      nodes = UC3Query::QueryClient.client.run_query('/queries/benchmark-fixity', params)

      desc << "## Benchmark Fixity Check"
      desc << "This report will perform a retrieval of the file from each ONLINE storage node using the ACCESS service." 
      desc << ""
      desc << "This report will perform a fixit of the file from each ONLINE storage node using the AUDIT service." 
      desc << ""
      desc << "Each request will be allowed up to 5 minutes to complete before timing out." 
      desc << ""

      if nodes
        desc << "These scripts can be used to test retrival of the same object using the S3 CLI."
        nodes.each do |node|
          benchmark_script(
            node['node_number'], 
            node['object_ark'], 
            node['version_number'], 
            node['pathname']
          ).each do |line|
            desc << line
          end
        end
      end
      table = AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:node_number, header: 'Node Number'),
          AdminUI::Column.new(:description, header: 'Description'),
          AdminUI::Column.new(:access_mode, header: 'Access Mode'),
          AdminUI::Column.new(:size, header: 'Size'),
          AdminUI::Column.new(:size_processed, header: 'Size Processed'),
          AdminUI::Column.new(:fixity_status, header: 'Status'),
          AdminUI::Column.new(:time_sec, header: 'Time (sec)'),
          AdminUI::Column.new(:benchmark_sec, header: 'Benchmark (sec)'),
          AdminUI::Column.new(:status, header: 'Status')
        ],
        description: desc.join("\n")
      )

      nodes.each do |node|
        row = {}
        row[:status] = 'SKIP'
        row[:node_number] = node['node_number'].to_s
        row[:description] = node['description']
        row[:access_mode] = node['access_mode']
        row[:size] = node['full_size']
        url = ''
        begin
          if node['access_mode'] == 'on-line'
            if node['full_size'].to_i > 500_000_000
              row[:fixity_status] = 'File too large to benchmark (>500MB).  Use the CLI.'
            else
              timing = Benchmark.realtime do
                key = CGI.escape("#{node['object_ark']}|#{node['version_number']}|#{node['pathname']}")
                url = "#{access_host}/presign-file/#{node['node_number']}/#{key}"
                row[:size_processed] = get_presign_url_content(url).length
              end
              row[:fixity_status] = 'Access Request'
              row[:time_sec] = timing
            end
          end
        rescue StandardError => e
          row[:fixity_status] = "Retrieve request #{url} did not complete: #{e}"
          row[:status] = 'FAIL'
        end
        table.add_row(AdminUI::Row.make_row(table.columns, row))

        row = {}
        row[:status] = 'SKIP'
        row[:node_number] = node['node_number'].to_s
        row[:description] = node['description']
        row[:access_mode] = node['access_mode']
        row[:size] = node['full_size']
        begin
          timing = Benchmark.realtime do
            json = post_url_json("#{audit_host}/update/#{node['id']}?t=json", read_timeout: 300)
            entry = json.fetch('items:fixityEntriesState', {})
              .fetch('items:entries', {})
              .fetch('items:fixityMRTEntry', {})
            row[:fixity_status] = entry.fetch('items:status', '')
            row[:size_processed] = entry.fetch('items:size', 0)
            row[:benchmark_sec] = 1.0
          end
          row[:time_sec] = timing
          row[:status] = if row[:fixity_status] != 'verified'
                           'FAIL'
                         elsif row[:time_sec] > row[:benchmark_sec]
                           'WARN'
                         else
                           'PASS'
                         end
        rescue StandardError => e
          row[:fixity_status] = "Fixity stream request did not complete: #{e}"
          row[:status] = 'FAIL'
        end
        table.add_row(AdminUI::Row.make_row(table.columns, row))
      end
      table
    end

    def load_test_file_to_merritt(file, type, mnemonic)
      puts "Loading #{file} to #{mnemonic} #{ui_host}/object/update"

      puts `curl -H 'Accept: application/json' \
        -F 'file=@#{file}' \
        -F 'title=#{type}: #{file}' \
        -F 'submitter=merritt-test' \
        -F 'responseForm=xml' \
        -F 'profile=#{mnemonic}_content' \
        --user 'merritt-test:password' #{ui_host}/object/update
      `
    end

    def manifest_url(node_number, ark)
      "#{store_host}/manifest/#{node_number}/#{CGI.escape(ark)}"
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
          if qc.run_query('/init/check-nodes').empty?
            qc.query_update('/init/create-nodes', purpose: 'Add Test Storage Nodes')
            resp << { action: 'Add test storage nodes', result: 'success' }
          else
            resp << { action: 'Add test storage nodes', result: 'skipped - already exists' }
          end

          if qc.run_query('/init/check-node-counts').empty?
            qc.query_update('/init/create-node-counts', purpose: 'Add Test Storage Node Counts')
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
          resp << ::JSON.parse(r.body)
        rescue StandardError => e
          resp << { action: "Create Collection #{c[:name]}", error: e.to_s }
        end
        begin
          params = {}
          params['ark'] = c[:ark]
          r = UC3Query::QueryClient.client.query_update(
            '/init/create-collection-nodes',
            params,
            purpose: "Create Storage Nodes for Collection #{c[:ark]}"
          )
          resp << r
        rescue StandardError => e
          resp << { action: "Create Storage Nodes for Collection #{c[:name]}", error: e.to_s }
        end
      end
      resp
    end

    def get_url_body(url)
      uri = URI.parse(url)
      response = Net::HTTP.get_response(uri)
      response.body
    end

    def get_presign_url_content(url, limit = 3)
      raise ArgumentError, 'HTTP redirect too deep' if limit <= 0

      uri = URI.parse(url)
      response = Net::HTTP.get_response(uri)
      json = ::JSON.parse(response.body)
      purl = json.fetch('url', '')
      return '' if purl.empty?

      get_url_body(purl)
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

    # this method may be over-customized for EZID.  Consider refactoring.
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

    def post_url_json(url, read_timeout: 120)
      uri = URI.parse(url)
      req = Net::HTTP::Post.new(uri)

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
        http.read_timeout = read_timeout
        http.request(req)
      end
      ::JSON.parse(response.body)
    end

    def post_url_message(url, body: nil, user: nil, password: nil, message: '')
      jsonbody = post_url_body(url, body: body, user: user, password: password)
      json = ::JSON.parse(jsonbody)
      json['message'] = message unless message.empty?
      json.to_json
    end

    def delete_url_resp(url, body: nil)
      uri = URI.parse(url)
      puts "Delete URI: #{url}, body: #{body}"
      req = Net::HTTP::Delete.new(uri)
      req['Content-Type'] = '*/*'
      # req['Accept'] = 'text/plain'
      req.body = body

      Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
        http.request(req)
      end
    end

    def delete_url_message(url, body: nil, message: '')
      resp = delete_url_resp(url, body: body)
      json = ::JSON.parse(resp.body)
      json['message'] = message unless message.empty?
      json.to_json
    end

    def post_url_multipart(url, params)
      puts "Multipart POST #{url} with #{params.inspect}"
      uri = URI.parse(url)
      req = Net::HTTP::Post::Multipart.new(uri, params)
      Net::HTTP.start(uri.hostname, uri.port) do |http|
        http.request(req)
      end
    end
  end

  register UC3ServicesRoutes
end
