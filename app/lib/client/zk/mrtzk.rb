# frozen_string_literal: true

require 'zk'
require 'merritt_zk'
require 'yaml'
require_relative '../uc3_client'
require_relative '../../ui/context'

# Scope custom code for UC3 to distinguish from 3rd party classes
module UC3Queue
  # Query for ZK nodes
  # VPC peering does not allow this, so this connection will not work until ZK is running in the UC3
  class ZKClient < UC3::UC3Client
    AGE_BATCHWARN = 3600 * 24 # 1 hour in seconds, converted to days
    TDESC = '[Merritt ZooKeeper Data Design](https://github.com/CDLUC3/mrt-zk/blob/main/design/data.md)'

    def self.client
      UC3::UC3Client.clients.fetch(self.class.to_s, ZKClient.new)
    end

    def initialize
      map = UC3::UC3Client.lookup_map_by_filename(
        'app/config/mrt/zk.lookup.yml',
        key: ENV.fetch('configkey', 'default')
      )
      @zkconn = map.fetch('zkconn', '')
      raise 'ZK connection string not defined' if @zkconn.empty?

      # NOTE: that this timeout (in sec) is for the creation of the connection
      ZK.open(@zkconn, timeout: 2) do |zk|
        raise "ZK init error #{@zkconn}" if zk.nil?
        raise "ZK connection error #{@zkconn}" unless zk.connected?
      end

      @zk_hosts = []
      @zkconn.split(',').each do |zkhost|
        @zk_hosts << zkhost.split(':').first
      end
      @admin_port = map.fetch('admin_port', 8080)
      @admin_user = map.fetch('admin_user', 'root')
      @admin_passwd = map.fetch('admin_passwd', 'root_passwd')
      @snapshot_path = map.fetch('snapshot_path', '/merritt-filesys/zk-snapshots')
      @cache = {}
      super(enabled: true)
    rescue StandardError => e
      puts "ZooKeeper Creation Error: #{e.message}"
      super(enabled: false, message: e.to_s)
    end

    def enabled
      ZK.open(@zkconn, timeout: 2) do |zk|
        zk.nil? ? false : zk.connected?
      end
    end

    def batches(route)
      batches = []
      ZK.open(@zkconn, timeout: 2) do |zk|
        batches = MerrittZK::Batch.list_batches_as_json(zk)
      end
      table = AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:id, header: 'Batch ID'),
          AdminUI::Column.new(:jobCount, header: 'Job Count', cssclass: 'int'),
          AdminUI::Column.new(:profile, header: 'Profile'),
          AdminUI::Column.new(:submissionDate, header: 'DateTime', cssclass: 'date'),
          AdminUI::Column.new(:type, header: 'Type'),
          AdminUI::Column.new(:jobdata, header: 'Job Data'),
          AdminUI::Column.new(:batch_status, header: 'Batch Status'),
          AdminUI::Column.new(:actions, header: 'Actions'),
          AdminUI::Column.new(:status, header: 'Status')
        ],
        status: 'PASS'
      )
      batches.each do |batch|
        status = batch[:status].to_s
        batch[:batch_status] = status
        batch[:status] = status == 'Failed' ? 'FAIL' : 'PASS'

        id = batch[:id]
        batch[:id] = {
          href: "/ops/zk/nodes/node-names?zkpath=/batches/#{batch[:id]}&mode=data",
          value: batch[:id]
        }
        batch[:submissionDate] = date_format(batch[:submissionDate])

        unless batch[:submissionDate].empty? || batch[:status] == 'FAIL'
          puts "Batch #{id} found, flagging for age"
          batch[:status] = 'WARN' if Time.now - Time.new(batch[:submissionDate]) > AGE_BATCHWARN
        end
        batch[:jobdata] = []
        batch[:jobdata] << batch[:submitter]
        batch[:jobdata] << batch[:creator]
        batch[:jobdata] << batch[:title]
        batch[:jobdata] << batch[:filename]
        batch[:actions] = []
        batch[:actions] << {
          value: 'Update Reporting',
          post: true,
          href: "/ops/zk/ingest/batch/update-reporting/#{id}",
          cssclass: 'button',
          disabled: !%w[Failed].include?(status)
        }
        batch[:actions] << {
          value: 'Queue Del',
          href: "/ops/zk/ingest/batch/delete/#{id}",
          post: true,
          cssclass: 'button',
          disabled: !%w[Failed Completed].include?(status)
        }
        table.add_row(
          AdminUI::Row.make_row(
            table.columns,
            batch
          )
        )
      end
      record_status(route, table.status)
      table
    end

    def jobs_by_collection(route, params)
      return jobs(params) unless params.empty?

      @colls = {}

      if enabled
        ZK.open(@zkconn, timeout: 2) do |zk|
          jobs = MerrittZK::Job.list_jobs_as_json(zk)
          jobs = [] if jobs.nil?
          jobs.each do |job|
            @colls[job[:profile]] ||= {}
            @colls[job[:profile]][job[:status]] ||= []
            @colls[job[:profile]][job[:status]] << job
          end
        end
        status = 'PASS'
      else
        status = 'ERROR'
      end

      table = AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:profile, header: 'Profile'),
          AdminUI::Column.new(:jobstatus, header: 'Job Status'),
          AdminUI::Column.new(:jobCount, header: 'Job Count', cssclass: 'int'),
          AdminUI::Column.new(:space_needed, header: 'Space Needed GB', cssclass: 'float'),
          AdminUI::Column.new(:status, header: 'Status')
        ],
        totals: true,
        status: status
      )
      @colls.keys.sort.each do |profile|
        @colls[profile].keys.sort.each do |jobstatus|
          job_count = @colls[profile][jobstatus].size
          space_needed = 0.0
          @colls[profile][jobstatus].each do |job|
            space_needed += job[:space_needed].to_f / 1_000_000_000
          end
          table.add_row(
            AdminUI::Row.make_row(
              table.columns,
              {
                profile: {
                  href: "/ops/zk/ingest/jobs-by-collection/filtered?profile=#{profile}",
                  value: profile
                },
                jobstatus: {
                  href: "/ops/zk/ingest/jobs-by-collection/filtered?profile=#{profile}&status=#{jobstatus}",
                  value: jobstatus
                },
                jobCount: job_count,
                space_needed: space_needed,
                status: jobstatus == 'Failed' ? 'FAIL' : 'PASS'
              }
            )
          )
        end
      end

      record_status(route, table.status)
      table
    end

    def jobs_by_collection_and_batch(route, params)
      return jobs(params) unless params.empty?

      @colls = {}

      if enabled
        ZK.open(@zkconn, timeout: 2) do |zk|
          jobs = MerrittZK::Job.list_jobs_as_json(zk)
          jobs = [] if jobs.nil?
          jobs.each do |job|
            key = "#{job[:profile]}:#{job[:bid]}"
            @colls[key] ||= {}
            @colls[key][job[:status]] ||= []
            @colls[key][job[:status]] << job
          end
        end
        status = 'PASS'
      else
        status = 'ERROR'
      end

      table = AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:profile, header: 'Profile'),
          AdminUI::Column.new(:bid, header: 'Batch ID'),
          AdminUI::Column.new(:jobstatus, header: 'Job Status'),
          AdminUI::Column.new(:jobCount, header: 'Job Count', cssclass: 'int'),
          AdminUI::Column.new(:space_needed, header: 'Space Needed GB', cssclass: 'float'),
          AdminUI::Column.new(:status, header: 'Status')
        ],
        totals: true,
        status: status
      )
      @colls.keys.sort.each do |key|
        profile, bid = key.split(':', 2)
        @colls[key].keys.sort.each do |jobstatus|
          job_count = @colls[key][jobstatus].size
          space_needed = 0.0
          @colls[key][jobstatus].each do |job|
            space_needed += job[:space_needed].to_f / 1_000_000_000
          end
          jcb = '/ops/zk/ingest/jobs-by-collection-and-batch/filtered'
          table.add_row(
            AdminUI::Row.make_row(
              table.columns,
              {
                profile: profile,
                bid: {
                  href: "#{jcb}?profile=#{profile}&bid=#{bid}",
                  value: bid
                },
                jobstatus: {
                  href: "#{jcb}?profile=#{profile}&bid=#{bid}&status=#{jobstatus}",
                  value: jobstatus
                },
                jobCount: job_count,
                space_needed: space_needed,
                status: jobstatus == 'Failed' ? 'FAIL' : 'PASS'
              }
            )
          )
        end
      end

      record_status(route, table.status)
      table
    end

    def jobs(params)
      jobs = []
      if enabled
        ZK.open(@zkconn, timeout: 2) do |zk|
          jobs = MerrittZK::Job.list_jobs_as_json(zk)
        end
        status = 'PASS'
      else
        status = 'ERROR'
      end
      table = AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:bid, header: 'Batch ID'),
          AdminUI::Column.new(:id, header: 'Job ID'),
          AdminUI::Column.new(:status, header: 'Status'),
          AdminUI::Column.new(:profile, header: 'Profile'),
          AdminUI::Column.new(:submissionDate, header: 'DateTime', cssclass: 'date'),
          AdminUI::Column.new(:type, header: 'Type'),
          AdminUI::Column.new(:jobdata, header: 'Job Data'),
          AdminUI::Column.new(:priority, header: 'Priority', cssclass: 'int'),
          AdminUI::Column.new(:space_needed, header: 'Space Needed GB', cssclass: 'float'),
          AdminUI::Column.new(:actions, header: 'Actions')
        ],
        status: status
      )
      jobs = [] if jobs.nil?
      jobs.each do |job|
        next unless params.fetch('profile', job[:profile]) == job[:profile]
        next unless params.fetch('status', job[:status]) == job[:status]
        next unless params.fetch('bid', job[:bid]) == job[:bid]

        id = job[:id]
        status = job[:status].to_s

        job[:id] = {
          href: "/ops/zk/nodes/node-names?zkpath=/jobs/#{job[:id]}&mode=data",
          value: job[:id]
        }
        job[:bid] = {
          href: "/ops/zk/nodes/node-names?zkpath=/batches/#{job[:bid]}&mode=data",
          value: job[:bid]
        }
        job[:submissionDate] = date_format(job[:submissionDate])
        job[:space_needed] = job[:space_needed].to_f / 1_000_000_000
        job[:jobdata] = []
        job[:jobdata] << job[:objectID]
        job[:jobdata] << job[:submitter]
        job[:jobdata] << job[:creator]
        job[:jobdata] << job[:title]
        job[:jobdata] << job[:filename]
        job[:actions] = []

        if %w[Failed].include?(status)
          job[:actions] << {
            value: 'Requeue',
            href: "/ops/zk/ingest/job/requeue/#{id}",
            post: true,
            cssclass: 'button requeue_button'
          }
        end

        if %w[Failed Completed].include?(status)
          job[:actions] << {
            value: 'Queue Del',
            href: "/ops/zk/ingest/job/delete/#{id}",
            post: true,
            cssclass: 'button delete_button'
          }
        end

        if %w[Pending].include?(status)
          job[:actions] << {
            value: 'Hold',
            href: "/ops/zk/ingest/job/hold/#{id}",
            post: true,
            cssclass: 'button hold_button'
          }
        end

        if %w[Held].include?(status)
          job[:actions] << {
            value: 'Release',
            href: "/ops/zk/ingest/job/release/#{id}",
            post: true,
            cssclass: 'button release_button'
          }
        end

        unless %w[Held Deleted Completed Failed].include?(status)
          job[:actions] << {
            value: 'Fail',
            title: 'Force job into Failed State',
            href: "/ops/zk/ingest/job/fail/#{id}",
            post: true,
            cssclass: 'button button_red fail_button',
            confmsg: 'Be very careful when forcing a failure on a job.  Do you want to proceed?'
          }
        end

        table.add_row(
          AdminUI::Row.make_row(
            table.columns,
            job
          )
        )
      end
      table
    end

    def assembly_requests(route)
      jobs = []
      if enabled
        begin
          ZK.open(@zkconn, timeout: 2) do |zk|
            jobs = MerrittZK::Access.list_jobs_as_json(zk)
          end
        rescue StandardError
          # handle case where no jobs exception is thrown
        end
        status = 'PASS'
      else
        status = 'ERROR'
      end
      table = AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:id, header: 'ID'),
          AdminUI::Column.new(:token, header: 'Token'),
          AdminUI::Column.new(:bytes, header: 'Bytes GB', cssclass: 'float'),
          AdminUI::Column.new(:queue_status, header: 'Queue Status'),
          AdminUI::Column.new(:date, header: 'DateTime', cssclass: 'date'),
          AdminUI::Column.new(:actions, header: 'Actions'),
          AdminUI::Column.new(:status, header: 'Status')
        ],
        status: status
      )
      jobs = [] if jobs.nil?
      jobs.each do |job|
        status = job[:status].to_s
        qn = job[:queueNode].gsub('/access/', '')
        id = job[:id]
        job[:queue_status] = status
        job[:id] = {
          href: "/ops/zk/nodes/node-names?zkpath=#{job[:queueNode]}/#{job[:id]}&mode=data",
          value: "#{qn} #{job[:id]}"
        }
        job[:date] = date_format(job[:date])
        job[:bytes] = job[:bytes].to_f / 1_000_000_000
        job[:actions] = []
        job[:actions] << {
          value: 'Requeue',
          href: "/ops/zk/access/requeue/#{qn}/#{id}",
          post: true,
          cssclass: 'button',
          disabled: !%w[Failed Consumed].include?(status)
        }
        job[:actions] << {
          value: 'Queue Del',
          href: "/ops/zk/access/delete/#{qn}/#{id}",
          post: true,
          cssclass: 'button',
          disabled: !%w[Failed Completed].include?(status)
        }

        job[:status] = 'PASS'

        table.add_row(
          AdminUI::Row.make_row(
            table.columns,
            job
          )
        )
      end
      record_status(route, table.status)
      table
    end

    def dump_node_table(nodedump, status)
      table = AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:node, header: 'Node'),
          AdminUI::Column.new(:ref, header: 'Reference')
        ],
        status: status,
        description: TDESC
      )
      nodedump.each do |node|
        next unless node.is_a?(String)

        table.add_row(
          AdminUI::Row.make_row(
            table.columns,
            {
              node: node,
              ref: make_ref(node)
            }
          )
        )
      end
      table
    end

    def dump_node_data_table(nodedump, status, mod: false)
      cols = [
        AdminUI::Column.new(:node, header: 'Node'),
        AdminUI::Column.new(:nodedata, header: 'Node Data'),
        AdminUI::Column.new(:ref, header: 'Reference')
        ]
      cols << AdminUI::Column.new(:action, header: 'Action') if mod
      table = AdminUI::FilterTable.new(
        columns: cols,
        status: status,
        description: TDESC
      )
      nodedump.each do |row|
        row.each do |node, value|
          next if node == 'Status'

          data = {
            node: node,
            ref: make_ref(node).empty? ? make_ref(value) : make_ref(node),
            nodedata: JSON.pretty_generate(value)
          }
          if mod
            data[:action] = {
              value: 'Delete',
              href: '/ops/zk/nodes/delete',
              post: true,
              cssclass: 'button',
              confmsg: "Are you sure you want to delete #{node} and any of its child nodes?",
              data: node
            }
          end
          table.add_row(
            AdminUI::Row.make_row(
              table.columns,
              data
            )
          )
        end
      end
      table
    end

    def dump_node_test_table(route, nodedump, status)
      table = AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:path, header: 'Path'),
          AdminUI::Column.new(:created, header: 'Created'),
          AdminUI::Column.new(:orphanpath, header: 'Orphan Path'),
          AdminUI::Column.new(:test, header: 'Test'),
          AdminUI::Column.new(:status, header: 'Status'),
          AdminUI::Column.new(:ref, header: 'Reference')
        ],
        status: status
      )
      nodedump.each do |node|
        value = node.values.first
        next unless value.is_a?(Array)

        match = %r{^(/batches/bid[0-9]+|/jobs/jid[0-9]+)(/|$)}.match(value[0])
        ref = match ? match[1] : ''

        table.add_row(
          AdminUI::Row.make_row(
            table.columns,
            {
              path: value[0],
              created: value[1],
              orphanpath:
                if value[2].empty?
                  ''
                else
                  {
                    value: "Delete #{value[2]}",
                    href: '/ops/zk/nodes/delete',
                    data: value[2],
                    post: true,
                    confmsg: "Are you sure you want to delete #{value[2]}",
                    cssclass: 'button'
                  }
                end,
              test: value[3],
              status: value[4],
              ref:
                if ref.empty?
                  ''
                else
                  {
                    href: "/ops/zk/nodes/node-names?zkpath=#{ref}&mode=data&mod=true",
                    value: ref
                  }
                end
            }
          )
        )
      end
      record_status(route, table.status)
      table
    end

    def make_ref(node)
      return '' unless node.is_a?(String)

      m = /(bid[0-9]+)$/.match(node)
      return { href: "/ops/zk/nodes/node-names?zkpath=/batches/#{m[1]}&mode=data", value: "/batches/#{m[1]}" } if m

      m = /(jid[0-9]+)$/.match(node)
      return { href: "/ops/zk/nodes/node-names?zkpath=/jobs/#{m[1]}&mode=data", value: "/jobs/#{m[1]}" } if m

      m = /(qid[0-9]+)$/.match(node)
      return { href: "/ops/zk/nodes/node-names?zkpath=#{node}&mode=data", value: m[1].to_s } if m

      ''
    end

    def dump_nodes(route, params)
      nodedump = []
      if enabled
        ZK.open(@zkconn, timeout: 2) do |zk|
          nodedump = MerrittZK::NodeDump.new(zk, params).listing
        end
        status = 'PASS'
      end

      case params.fetch('mode', 'node')
      when 'data'
        dump_node_data_table(nodedump, status, mod: params.key?('mod'))
      when 'test'
        dump_node_test_table(route, nodedump, status)
      else
        dump_node_table(nodedump, status)
      end
    end

    def pause_ingest
      ZK.open(@zkconn, timeout: 2) do |zk|
        MerrittZK::Locks.lock_ingest_queue(zk)
      end
    end

    def unpause_ingest
      ZK.open(@zkconn, timeout: 2) do |zk|
        MerrittZK::Locks.unlock_ingest_queue(zk)
      end
    end

    def cleanup_ingest_queue
      ZK.open(@zkconn, timeout: 2) do |zk|
        MerrittZK::Batch.delete_completed_batches(zk)
      end
    end

    def pause_access_small
      ZK.open(@zkconn, timeout: 2) do |zk|
        MerrittZK::Locks.lock_small_access_queue(zk)
      end
    end

    def unpause_access_small
      ZK.open(@zkconn, timeout: 2) do |zk|
        MerrittZK::Locks.unlock_small_access_queue(zk)
      end
    end

    def pause_access_large
      ZK.open(@zkconn, timeout: 2) do |zk|
        MerrittZK::Locks.lock_large_access_queue(zk)
      end
    end

    def unpause_access_large
      ZK.open(@zkconn, timeout: 2) do |zk|
        MerrittZK::Locks.unlock_large_access_queue(zk)
      end
    end

    def cleanup_access_queue
      ZK.open(@zkconn, timeout: 2) do |zk|
        puts 'Cleaning up access jobs'
        jobs = MerrittZK::Access.list_jobs_as_json(zk)
        jobs = [] if jobs.nil?
        jobs.each do |job|
          qn = job.fetch(:queueNode, MerrittZK::Access::SMALL).gsub(%r{^/access/}, '')
          j = MerrittZK::Access.new(qn, job.fetch(:id, ''))
          j.load(zk)
          next unless j.status.deletable?

          j.delete(zk)
        end
      end
    end

    def delete_access(queuename, queueid)
      ZK.open(@zkconn, timeout: 2) do |zk|
        j = MerrittZK::Access.new(queuename, queueid)
        j.load(zk)
        j.set_status(zk, MerrittZK::AccessState::Deleted)
      end
    end

    def delete_ingest_job(queueid)
      ZK.open(@zkconn, timeout: 2) do |zk|
        j = MerrittZK::Job.new(queueid)
        j.load(zk)
        j.set_status(zk, MerrittZK::JobState::Deleted)
      end
    end

    def requeue_ingest_job(queueid)
      ZK.open(@zkconn, timeout: 2) do |zk|
        job = MerrittZK::Job.new(queueid)
        job.load(zk)

        js = job.json_property(zk, MerrittZK::ZkKeys::STATUS)
        laststat = js.fetch(:last_successful_status, '')

        job.lock(zk)

        case laststat
        when 'Pending', '', nil
          job.set_status(zk, MerrittZK::JobState::Estimating, job_retry: true)
        when 'Estimating'
          job.set_status(zk, MerrittZK::JobState::Provisioning, job_retry: true)
        when 'Provisioning'
          job.set_status(zk, MerrittZK::JobState::Downloading, job_retry: true)
        when 'Downloading'
          job.set_status(zk, MerrittZK::JobState::Processing, job_retry: true)
        when 'Processing'
          job.set_status(zk, MerrittZK::JobState::Storing, job_retry: true)
        when 'Storing'
          job.set_status(zk, MerrittZK::JobState::Recording, job_retry: true)
        when 'Recording'
          job.set_status(zk, MerrittZK::JobState::Notify, job_retry: true)
        end

        job.unlock(zk)
      end
    end

    def hold_ingest_job(queueid)
      ZK.open(@zkconn, timeout: 2) do |zk|
        j = MerrittZK::Job.new(queueid)
        j.load(zk)
        j.set_status(zk, MerrittZK::JobState::Held)
      end
    end

    def fail_ingest_job(queueid)
      ZK.open(@zkconn, timeout: 2) do |zk|
        j = MerrittZK::Job.new(queueid)
        j.load(zk)
        j.set_status(zk, MerrittZK::JobState::Failed)
      end
    end

    def release_ingest_job(queueid)
      ZK.open(@zkconn, timeout: 2) do |zk|
        j = MerrittZK::Job.new(queueid)
        j.load(zk)
        j.set_status(zk, MerrittZK::JobState::Pending)
      end
    end

    def delete_ingest_batch(queueid)
      ZK.open(@zkconn, timeout: 2) do |zk|
        b = MerrittZK::Batch.new(queueid)
        b.load(zk)
        b.set_status(zk, MerrittZK::BatchState::Deleted)
      end
    end

    def update_reporting_ingest_batch(queueid)
      ZK.open(@zkconn, timeout: 2) do |zk|
        b = MerrittZK::Batch.new(queueid)
        b.load(zk)
        b.set_status(zk, MerrittZK::BatchState::UpdateReporting)
      end
    end

    def requeue_access(queuename, queueid)
      ZK.open(@zkconn, timeout: 2) do |zk|
        j = MerrittZK::Access.new(queuename, queueid)
        j.load(zk)
        j.set_status(zk, MerrittZK::AccessState::Pending)
      end
    end

    def fake_access
      ZK.open(@zkconn, timeout: 2) do |zk|
        MerrittZK::Access.create_assembly(
          zk,
          MerrittZK::Access::SMALL,
          {
            'cloud-content-byte': 17_079,
            'delivery-node': 7777,
            status: 201,
            token: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
          }
        )
      end
    end

    def zk_auth
      "'Authorization: digest #{@admin_user}:#{@admin_passwd}'"
    end

    def save_snapshot
      `mkdir -p #{@snapshot_path}`
      url = "http://#{@zk_hosts.first}:#{@admin_port}/commands/snapshot?streaming=true"
      path = "#{@snapshot_path}/latest_snapshot.#{UC3::UC3Client.stack_name}.#{Time.new.strftime('%Y-%m-%d_%H:%M:%S')}.out"
      path_ln = "#{@snapshot_path}/latest_snapshot.#{UC3::UC3Client.stack_name}.out"
      puts `curl -H #{zk_auth} #{url} --output #{path} && rm #{path_ln} && ln -s #{path} #{path_ln}`
    end

    def restore_from_snapshot
      ct = "'Content-Type:application/octet-stream'"
      path = "#{@snapshot_path}/latest_snapshot.#{UC3::UC3Client.stack_name}.out"
      @zk_hosts.each do |zkhost|
        url = "http://#{zkhost}:#{@admin_port}/commands/restore"
        puts `curl -H #{ct} -H #{zk_auth} -POST #{url} --data-binary "@#{path}"`
      end
    end

    def zk_stat
      data = []
      @zk_hosts.each do |zkhost|
        data << {
          conf: JSON.parse(`curl -H #{zk_auth} http://#{zkhost}:#{@admin_port}/commands/conf`),
          lead: JSON.parse(`curl -H #{zk_auth} http://#{zkhost}:#{@admin_port}/commands/lead`),
          lsnp: JSON.parse(`curl -H #{zk_auth} http://#{zkhost}:#{@admin_port}/commands/lsnp`),
          stat: JSON.parse(`curl -H #{zk_auth} http://#{zkhost}:#{@admin_port}/commands/stat`)
        }
      rescue StandardError => e
        data << { error: "Error connecting to ZK host #{zkhost}: #{e.message}" }
      end
      data
    end

    def create_node(path, data: nil)
      ZK.open(@zkconn, timeout: 2) do |zk|
        break if zk.exists?(path)

        if data.nil?
          zk.create(path)
        else
          zk.create(path, data: data)
        end
      end
    rescue StandardError => e
      puts "Error creating node #{path}: #{e.message}"
    end

    def delete_node(path)
      ZK.open(@zkconn, timeout: 2) do |zk|
        break if path.split('/').length < 2

        zk.rm_rf(path) if zk.exists?(path)
      end
    rescue StandardError => e
      puts "Error deleting node #{path}: #{e.message}"
    end

    def lock_collection(mnemonic)
      return if mnemonic.nil?
      return if mnemonic.empty?

      ZK.open(@zkconn, timeout: 2) do |zk|
        MerrittZK::Locks.lock_collection(zk, mnemonic)
      end
    rescue StandardError => e
      puts "Error locking collection #{mnemonic}: #{e.message}"
    end

    def unlock_collection(mnemonic)
      return if mnemonic.nil?
      return if mnemonic.empty?

      ZK.open(@zkconn, timeout: 2) do |zk|
        MerrittZK::Locks.unlock_collection(zk, mnemonic)
      end
    rescue StandardError => e
      puts "Error unlocking collection #{mnemonic}: #{e.message}"
    end

    def clear_cache
      @cache = {}
    end

    def locked_collections
      locked = @cache[:locked]
      return locked unless locked.nil?

      locked = {}
      ZK.open(@zkconn, timeout: 2) do |zk|
        params = {}
        params['zkpath'] = '/locks/collections'
        MerrittZK::NodeDump.new(zk, params).listing.each do |coll|
          coll.each_key do |path|
            locked[path.split('/')[-1]] = true
          end
        end
      end
      @cache[:locked] = locked
      locked
    rescue StandardError => e
      puts "Error listing locked collections: #{e.message}"
    end
  end
end
