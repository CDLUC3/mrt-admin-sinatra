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
    MONITOR_OPEN_TIMEOUT = 2
    MONITOR_READ_TIMEOUT = 5

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
        # Per David, replic uses status instead of state
        get_url("#{replic_host}/status?t=json")
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

        { message: 'nodenum and ark are required' }.to_json if nodenum.empty? || ark.empty?

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

      app.post '/ops/inventory/delete' do
        raise 'Delete Not allowed' if UC3Query::QueryResolvers.object_delete_disabled?

        nodenum = request.params.fetch('node_number', '')
        ark = request.params.fetch('ark', '')

        content_type :json
        delete_object(ark, nodenum).to_json
      rescue StandardError => e
        { message: "FAIL: (#{e})" }.to_json
      end

      app.get '/ops/inventory/delete-lists' do
        table = UC3S3::ConfigObjectsClient.client.review_delete_lists
        adminui_show_table(
          AdminUI::Context.new(request.path, request.params),
          table
        )
      end

      app.get '/ops/inventory/list-delete-lists' do
        content_type :json
        UC3S3::ConfigObjectsClient.client.list_delete_lists.to_json
      end

      app.get '/ops/inventory/delete-lists/*' do |list_name|
        table = UC3S3::ConfigObjectsClient.client.review_delete_list(list_name)
        adminui_show_table(
          AdminUI::Context.new(request.path, request.params),
          table
        )
      end

      app.get '/ops/inventory/delete-list/*' do |list_name|
        content_type :json
        UC3S3::ConfigObjectsClient.client.get_delete_list(list_name).to_json
      end

      app.post '/test/purge/*' do |mnemonic|
        urlparams = {}
        urlparams['count'] = [50, request.params.fetch('count', '20').to_i].min
        urlparams['mnemonic'] = mnemonic
        resp = UC3Query::QueryClient.client.run_query('/queries/misc/purgable_arks', urlparams).map do |row|
          delete_object(row['ark'], row['nodenum'].to_s)
        end
        puts resp
        resp.to_json
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
          row[:profile] = 'sdsc-s3' if %w[7501 7502].include?(row[:node_number])
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

        desc = '[Creating a merritt-ops session for this stack](/#create-ops)'

        table = AdminUI::FilterTable.new(
          columns: [
            AdminUI::Column.new(:description, header: 'Description'),
            AdminUI::Column.new(:node_number, header: 'Node Number'),
            AdminUI::Column.new(:bucket, header: 'Bucket'),
            AdminUI::Column.new(:profile, header: 'Profile'),
            AdminUI::Column.new(:command, header: 'Command')
          ],
          description: desc
        )
        rows.each do |row|
          cmd = "aws s3#{" --profile #{row[:profile]}" unless row[:profile].empty?} ls s3://#{row[:bucket]}/"
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
        data = benchmark_fixity_data(request, '/queries/benchmark-fixity', path: '/ops/storage/benchmark-fixity-fileid')
        filename = data.fetch(:filename, '')
        size = AdminUI::Row.format_int(data.fetch(:file_size, ''))
        table = AdminUI::FilterTable.new(
          columns: [
            AdminUI::Column.new(:node_number, header: 'Node Number'),
            AdminUI::Column.new(:cloud_service, header: 'Cloud Service'),
            AdminUI::Column.new(:admin_audit_url, header: 'Audit Test'),
            AdminUI::Column.new(:admin_access_url, header: 'Access Test'),
            AdminUI::Column.new(:cli_command, header: 'CLI command')
          ],
          description: "Check Fixity for File `#{filename}`; Size=`#{size}`"
        )
        data.fetch(:nodes, {}).each_value do |node_data|
          node_data[:admin_audit_url] = { href: node_data[:admin_audit_url], value: 'Audit Benchmark' }
          node_data[:admin_access_url] = { href: node_data[:admin_access_url], value: 'Access Benchmark' }
          table.add_row(
            AdminUI::Row.make_row(
              table.columns,
              node_data
            )
          )
        end
        adminui_show_table(
          AdminUI::Context.new(request.path, request.params),
          table
        )
      end

      app.get '/ops/storage/benchmark-fixity-fileid' do
        content_type :json
        benchmark_fixity_data(request, '/queries/benchmark-fixity').to_json
      end

      app.get '/ops/storage/benchmark-fixity-localid' do
        content_type :json
        benchmark_fixity_data(request, '/ops/storage/benchmark-fixity-nodes').to_json
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

      app.get '/ops/monitoring/service-status' do
        states = []

        states << check_mysql
        states << check_zk
        states << check_ldap

        states << monitor_service_status(:ui, :state, "#{ui_host}/state.json")
        states << monitor_service_status(:ingest, :state, "#{ingest_host}/state?t=json")
        states << monitor_service_status(:store, :state, "#{store_host}/state?t=json")
        states << monitor_service_status(:access, :state, "#{access_host}/state?t=json")

        # Per David, state and status are equivalent
        states << monitor_service_status(:audit, :state, "#{audit_host}/state?t=json")
        states << monitor_service_status(:replic, :status, "#{replic_host}/status?t=json")
        states << monitor_service_status(:inventory, :state, "#{inventory_host}/state?t=json")

        adminui_show_table(
          AdminUI::Context.new(request.path, request.params),
          monitor_service_table(states)
        )
      end

      app.get '/state' do
        content_type :json

        admin_state.to_json
      end
    end

    def admin_state
      {
        stack: UC3::UC3Client.stack_name,
        mysql: check_mysql.fetch(:state, ''),
        zk: check_zk.fetch(:state, ''),
        ldap: check_ldap.fetch(:state, '')
      }
    end

    def check_ldap
      timing = Benchmark.realtime do
        UC3Ldap::LDAPClient.client.load_users
      end
      { service: 'LDAP', status: 'PASS', message: 'Connection verified', state: 'running', timing: timing }
    rescue StandardError => e
      { service: 'LDAP', status: 'FAIL', message: "Load Error: #{e.message}", state: 'not-running', timing: timing }
    end

    def check_mysql
      timing = Benchmark.realtime do
        UC3Query::QueryClient.client.run_query('/queries/misc/now', {})
      end
      { service: 'MySQL', status: 'PASS', message: 'Connection verified', state: 'running', timing: timing }
    rescue StandardError => e
      { service: 'MySQL', status: 'FAIL', message: "Load Error: #{e.message}", state: 'not-running', timing: timing }
    end

    def check_zk
      # this should return a fairly small payload
      timing = Benchmark.realtime do
        UC3Queue::ZKClient.client.locked_collections
      end
      { service: 'ZK', status: 'PASS', message: 'Connection verified', state: 'running', timing: timing }
    rescue StandardError => e
      { service: 'ZK', status: 'FAIL', message: "Load Error: #{e.message}", state: 'not-running', timing: timing }
    end

    def monitor_service_status(service, checkname, url, read_timeout: MONITOR_READ_TIMEOUT,
      open_timeout: MONITOR_OPEN_TIMEOUT)
      resp = get_url_timing(url, read_timeout: read_timeout, open_timeout: open_timeout)
      state = 'SKIP'
      unless resp[:error].empty?
        resp[:message] = resp[:error]
        state = 'FAIL'
      end
      state = 'PASS' if resp[:code] == 200

      unless resp[:body].empty?
        if service == :ui
          version = resp[:body].fetch('version', '')
          if version.empty?
            resp[:message] = 'UI version not found'
            state = 'FAIL'
          else
            resp[:message] = version
          end
        end

        if service == :ingest
          if checkname == :state
            svcstate = resp[:body].fetch('ing:ingestServiceState', {}).fetch('ing:submissionState', '')
            resp[:message] = "Ingest State: #{svcstate}"
            state = 'FAIL' if svcstate != 'thawed'
          else
            resp[:message] = "JSON returned for #{checkname}"
          end
        end

        if %i[store access].include?(service)
          if checkname == :state
            svcstate = resp[:body].fetch('sto:storageServiceState', {}).fetch('sto:failNodesCnt', 'Not Found').to_s
            resp[:message] = "Storage Failed Node Count: #{svcstate}"
            state = 'FAIL' if svcstate != '0'
          elsif checkname == :jsonstatus
            fail = resp[:body].fetch('failCnt', '0').to_s
            resp[:message] = "Fail Count: #{fail}"
            state = 'FAIL' if fail != '0'
          else
            resp[:message] = "JSON returned for #{checkname}"
          end
        end

        if service == :inventory
          if checkname == :state
            svcstate = resp[:body].fetch('invsv:invServiceState', {}).fetch('invsv:systemStatus', 'Not Found').to_s
            svcstate2 = resp[:body].fetch('invsv:invServiceState', {}).fetch('invsv:zookeeperStatus', 'Not Found').to_s
            resp[:message] = "Inventory States: DB: #{svcstate}, Zoo: #{svcstate2}"
            state = 'FAIL' if svcstate != 'running' || svcstate2 != 'running'
          else
            resp[:message] = "JSON returned for #{checkname}"
          end
        end

        if service == :audit
          if %i[state status].include?(checkname)
            svcstate = resp[:body].fetch('fix:fixityServiceState', {}).fetch('fix:status', 'Not Found').to_s
            resp[:message] = "Audit State: #{svcstate}"
            state = 'FAIL' if svcstate != 'running'
          else
            resp[:message] = "JSON returned for #{checkname}"
          end
        end

        if service == :replic
          if %i[state status].include?(checkname)
            svcstate = resp[:body].fetch('repsvc:replicationServiceState', {}).fetch('repsvc:status', 'Not Found').to_s
            resp[:message] = "Replic State: #{svcstate}"
            state = 'FAIL' if svcstate != 'running'
          elsif checkname == :jsonstatus
            fail = resp[:body].fetch('failCnt', '0').to_s
            resp[:message] = "Fail Count: #{fail}"
            state = 'FAIL' if fail != '0'
          else
            resp[:message] = "JSON returned for #{checkname}"
          end
        end
      end

      {
        service: service,
        url: url,
        code: resp[:code],
        timing: resp[:timing],
        message: resp[:message],
        status: state
      }
    end

    def monitor_service_table(states)
      desc = 'Service Status Monitor.  Open Timeout: ' \
             "#{MONITOR_OPEN_TIMEOUT} sec; Read Timeout: #{MONITOR_READ_TIMEOUT} sec"
      table = AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:service, header: 'Service'),
          AdminUI::Column.new(:url, header: 'URL'),
          AdminUI::Column.new(:code, header: 'HTTP Code'),
          AdminUI::Column.new(:timing, header: 'Response Time (sec)'),
          AdminUI::Column.new(:message, header: 'Message'),
          AdminUI::Column.new(:status, header: 'Status')
        ],
        description: desc
      )
      states.each do |state|
        table.add_row(
          AdminUI::Row.make_row(
            table.columns,
            state
          )
        )
      end
      table
    end

    def benchmark_fixity_data(request, query_name, path: '')
      path = request.path if path.empty?
      uri = "#{path}?#{request.query_string}"
      nodes = UC3Query::QueryClient.client.run_query(query_name, request.params)
      benchmark_data = benchmark_nodes(uri, nodes)

      node_number = request.params.fetch('node_number', '0').to_i
      retrieval_method = request.params.fetch('retrieval_method', '')

      return benchmark_data if node_number.zero?

      node_data = benchmark_data.fetch(:nodes, {}).fetch(node_number, {})

      return node_data if retrieval_method.empty?

      node_data[:results] = {}
      results_data = node_data[:results]

      case retrieval_method
      when 'access'
        begin
          chksize = 0
          timing = Benchmark.realtime do
            results_data[:presigned_url] = get_presign_url(URI.parse(node_data[:access_url]))
            chksize = get_url_body(results_data[:presigned_url]).length unless results_data[:presigned_url].empty?
          end

          results_data[:retrieval_time_sec] = timing
          results_data[:status] = if timing > 3 * node_data[:access_expected_retrieval_time_sec]
                                    'FAIL'
                                  elsif timing > 2 * node_data[:access_expected_retrieval_time_sec]
                                    'WARN'
                                  elsif timing > node_data[:access_expected_retrieval_time_sec]
                                    'INFO'
                                  else
                                    'PASS'
                                  end

          unless chksize == node_data[:file_size]
            results_data[:status] = 'ERROR'
            results_data[:error_message] = "File size mismatch: expected #{node_data[:file_size]}, got #{chksize}"
          end
          results_data[:retrieval_time_sec] = timing
        rescue StandardError => e
          results_data[:status] = 'ERROR'
          results_data[:error_message] = e.message
        end
      when 'audit'
        begin
          chksize = 0
          timing = Benchmark.realtime do
            json = post_url_json(node_data[:audit_url], read_timeout: 300)
            entry = json.fetch('items:fixityEntriesState', {})
              .fetch('items:entries', {})
              .fetch('items:fixityMRTEntry', {})
            results_data[:fixity_status] = entry.fetch('items:status', '')
            chksize = entry.fetch('items:size', 0)
          end

          results_data[:retrieval_time_sec] = timing
          results_data[:status] = if timing > 3 * node_data[:audit_expected_retrieval_time_sec]
                                    'FAIL'
                                  elsif timing > 2 * node_data[:audit_expected_retrieval_time_sec]
                                    'WARN'
                                  elsif timing > node_data[:audit_expected_retrieval_time_sec]
                                    'INFO'
                                  else
                                    'PASS'
                                  end

          unless chksize == node_data[:file_size]
            results_data[:status] = 'ERROR'
            results_data[:error_message] = "File size mismatch: expected #{node_data[:file_size]}, got #{chksize}"
          end
          unless results_data[:fixity_status] == 'verified'
            results_data[:status] = 'ERROR'
            results_data[:error_message] =
              "Fixity status mismatch: expected 'verified', got #{results_data[:fixity_status]}"
          end
        rescue StandardError => e
          results_data[:status] = 'ERROR'
          results_data[:error_message] = e.message
        end
      else
        return {}
      end
      node_data
    end

    def benchmark_bucket(nodenum)
      case nodenum
      when 9501, 9502, 9503
        ENV.fetch('SDSC_BUCKET', '')
      when 2001, 2002, 2003
        ENV.fetch('WASABI_BUCKET', '')
      when 5001, 5003
        ENV.fetch('S3_BUCKET', '')
      when 7777
        ENV.fetch('BUCKET7777', '')
      when 8888
        ENV.fetch('BUCKET8888', '')
      else
        ''
      end
    end

    def benchmark_path(nodenum, ark, version, pathname)
      bucket = benchmark_bucket(nodenum)
      return '' if bucket.empty?

      "s3://#{bucket}/#{ark}|#{version}|#{pathname}"
    end

    def benchmark_endpoint(nodenum)
      case nodenum
      when 9501, 9502, 9503
        ENV.fetch('SDSC_ENDPOINT', '')
      when 7501, 7502
        ENV.fetch('SDSC_S3_ENDPOINT', '')
      when 2001, 2002, 2003
        ENV.fetch('WASABI_ENDPOINT', '')
      when 7777, 8888
        ENV.fetch('S3ENDPOINT', '')
      else
        ''
      end
    end

    def cloud_service(nodenum)
      case nodenum
      when 9501, 9502, 9503
        'sdsc'
      when 7501, 7502
        'sdsc-s3'
      when 2001, 2002, 2003
        'wasabi'
      when 5001, 5003
        'aws-s3'
      when 6001
        'glacier'
      when 7777, 8888, 8889
        ENV.fetch('S3ENDPOINT', '').empty? ? 'aws-s3' : 'minio-docker'
      else
        nodenum.to_s
      end
    end

    def benchmark_expected_retrieval_time_sec(file_size, cloud_service, _method)
      base = case cloud_service
             when 'sdsc', 'sdsc-s3'
               0.6
             when 'wasabi'
               1.5
             else
               0.2
             end
      multiplier = case cloud_service
                   when 'sdsc', 'sdsc-s3'
                     0.000000024
                   when 'wasabi'
                     0.000000055
                   else
                     0.000000028
                   end
      base + (file_size * multiplier)
    end

    def benchmark_nodes(uri, nodes)
      resp = {}
      nodes.each_with_index do |node, index|
        if index.zero?
          resp[:filename] = File.basename(node['pathname'])
          resp[:pathname] = "#{node['object_ark']}|#{node['version_number']}|#{node['pathname']}"
          resp[:file_size] = node['full_size']
          resp[:nodes] = {}
        end
        next unless node['access_mode'] == 'on-line'

        bucket = benchmark_bucket(node['node_number'])
        profile = cloud_service(node['node_number'])
        profile = '' if profile == 'aws-s3'
        profile_str = profile.empty? ? '' : "--profile #{profile} "
        endpoint = benchmark_endpoint(node['node_number'])
        endpoint_str = endpoint.empty? ? '' : "--endpoint-url #{endpoint}"

        filesize = node['full_size']
        cloud_service = cloud_service(node['node_number'])

        resp[:nodes][node['node_number']] = {
          node_number: node['node_number'].to_s,
          filename: resp[:filename],
          pathname: bucket.empty? ? '' : "s3://#{bucket}/#{resp[:pathname]}",
          file_size: filesize,
          cloud_service: cloud_service(node['node_number']),
          profile: cloud_service(node['node_number']),
          endpoint: endpoint,
          access_url: "#{access_host}/presign-file/#{node['node_number']}/#{CGI.escape(resp[:pathname])}",
          admin_access_url: "#{uri}&node_number=#{node['node_number']}&retrieval_method=access",
          access_expected_retrieval_time_sec: benchmark_expected_retrieval_time_sec(filesize, cloud_service, 'audit'),
          audit_url: "#{audit_host}/update/#{node['id']}?t=json",
          admin_audit_url: "#{uri}&node_number=#{node['node_number']}&retrieval_method=audit",
          audit_expected_retrieval_time_sec: benchmark_expected_retrieval_time_sec(filesize, cloud_service, 'audit'),
          cli_command: "aws s3 #{profile_str} #{endpoint_str} cp s3://#{bucket}/#{resp[:pathname]} /dev/null"
        }
      end
      resp
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

    def get_presign_url(url)
      uri = URI.parse(url)
      response = Net::HTTP.get_response(uri)
      json = ::JSON.parse(response.body)
      json.fetch('url', '')
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

    def get_url_timing(url, read_timeout: MONITOR_READ_TIMEOUT, open_timeout: MONITOR_OPEN_TIMEOUT)
      status = {
        message: '',
        error: '',
        code: 0,
        body: {}
      }
      timing = Benchmark.realtime do
        uri = URI.parse(url)
        req = Net::HTTP::Get.new(uri)

        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
          http.read_timeout = read_timeout
          http.open_timeout = open_timeout
          http.request(req)
        end
        status[:code] = response.code.to_i
        status[:message] = response.message
        begin
          status[:body] = ::JSON.parse(response.body)
        rescue StandardError => e
          status[:error] = e.to_s
        end
      rescue StandardError => e
        status[:error] = e.to_s
      end
      status[:error] = 'Timeout' if status[:code].zero?
      status[:timing] = timing
      status
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

    def delete_object(ark, nodenum = '')
      raise 'Delete Not allowed' if UC3Query::QueryResolvers.object_delete_disabled?

      steps = []
      fail = false

      return { message: 'An ark is required for delete_object' } if ark.empty?

      if nodenum.empty?
        urlparams = {}
        urlparams['ark'] = ark
        UC3Query::QueryClient.client.run_query('/queries/misc/primary_node', urlparams).each do |row|
          nodenum = row['nodenum'].to_s
        end
      end

      return { message: "A primary node number was not found for #{ark}" } if nodenum.empty?

      arkenc = CGI.escape(ark)

      delete_url = "#{replic_host}/deletesecondary/#{arkenc}?t=json"

      if delete_url_resp(delete_url).code.to_i == 200
        steps << 'Delete of replicated copies'
      else
        steps << 'FAIL: Delete of replicated copies'
        fail = true
      end

      delete_url = "#{store_host}/content/#{nodenum}/#{arkenc}?t=json"

      if delete_url_resp(delete_url).code.to_i == 200
        steps << 'Delete of primary copy'
      else
        steps << 'FAIL: Delete of primary copy'
        fail = true
      end

      delete_url = "#{inventory_host}/object/#{arkenc}?t=json"

      if delete_url_resp(delete_url).code.to_i == 200
        steps << 'Delete of inventory'
      else
        steps << 'FAIL: Delete of inventory'
        fail = true
      end

      delete_url = "#{inventory_host}/primary/#{arkenc}?t=json"

      if delete_url_resp(delete_url).code.to_i == 200
        steps << 'Delete of local id'
      else
        steps << 'FAIL: Delete of localid'
        fail = true
      end

      if fail
        { message: "#{ark}: FAIL: (#{steps.join('; ')})" }
      else
        { message: "#{ark}: SUCCESS: (#{steps.join('; ')})" }
      end
    end
  end

  register UC3ServicesRoutes
end
