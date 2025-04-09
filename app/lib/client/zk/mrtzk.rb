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
    def self.client
      UC3::UC3Client.clients.fetch(self.class.to_s, ZKClient.new)
    end

    def initialize
      map = UC3::UC3Client.lookup_map_by_filename('app/config/mrt/zk.yml')
      @zk = ZK.new(map.fetch('zkconn', ''), timeout: 1)
      super(enabled: @zk.connected?)
    rescue StandardError => e
      super(enabled: false, message: e.to_s)
    end

    def batches
      batches = MerrittZK::Batch.list_batches_as_json(@zk)
      table = AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:id, header: 'Batch ID'),
          AdminUI::Column.new(:jobCount, header: 'Job Count', cssclass: 'int'),
          AdminUI::Column.new(:profile, header: 'Profile'),
          AdminUI::Column.new(:submissionDate, header: 'DateTime', cssclass: 'date'),
          AdminUI::Column.new(:type, header: 'Type'),
          AdminUI::Column.new(:jobdata, header: 'Job Data'),
          AdminUI::Column.new(:status, header: 'Status'),
          AdminUI::Column.new(:actions, header: 'Actions'),
        ]
      )
      batches.each do |batch|
        batch[:id] = {
          href: "/ops/zk/nodes/node-names?zkpath=/batches/#{batch[:id]}&mode=data", 
          value: batch[:id]
        }
        batch[:submissionDate] = date_format(batch[:submissionDate])
        batch[:jobdata] = []
        batch[:jobdata] << batch[:submitter]
        batch[:jobdata] << batch[:creator]
        batch[:jobdata] << batch[:title]
        batch[:jobdata] << batch[:filename]
        batch[:actions] = []
        batch[:actions] << {
          value: 'Requeue',
          href: "#",
          cssclass: 'buttontbd',
          disabled: false
        }
        batch[:actions] << {
          value: 'Queue Del',
          href: "#",
          cssclass: 'buttontbd',
          disabled: false
        }
        table.add_row(
          AdminUI::Row.make_row(
            table.columns,
            batch
          )
        )
      end
      table
    end


    def jobs_by_collection(params)
      return jobs(params) unless params.empty?

      @colls = {}
      MerrittZK::Job.list_jobs_as_json(@zk).each do |job|
        @colls[job[:profile]] ||= {}
        @colls[job[:profile]][job[:status]] ||= []
        @colls[job[:profile]][job[:status]] << job
      end

      table = AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:profile, header: 'Profile'),
          AdminUI::Column.new(:jobstatus, header: 'Job Status'),
          AdminUI::Column.new(:jobCount, header: 'Job Count', cssclass: 'int'),
          AdminUI::Column.new(:status, header: 'Status')
        ]
      )
      @colls.keys.sort.each do |profile|
        @colls[profile].keys.sort.each do |jobstatus|
          job_count = @colls[profile][jobstatus].size
          table.add_row(
            AdminUI::Row.make_row(
              table.columns,
              {
                profile: {
                  href: "/ops/zk/ingest/jobs-by-collection?profile=#{profile}",
                  value: profile
                },
                jobstatus: {
                  href: "/ops/zk/ingest/jobs-by-collection?profile=#{profile}&status=#{jobstatus}",
                  value: jobstatus
                },
                jobCount: job_count,
                status: jobstatus == 'Failed' ? 'FAIL' : 'PASS'
              }
            )
          )
        end
      end
      table
    end

    def jobs(params)
      jobs = MerrittZK::Job.list_jobs_as_json(@zk)
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
          AdminUI::Column.new(:actions, header: 'Actions'),
        ]
      )
      jobs.each do |job|
        next unless params.fetch('profile', job[:profile]) == job[:profile]
        next unless params.fetch('status', job[:status]) == job[:status]

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
        job[:actions] << {
          value: 'Requeue',
          href: "#",
          cssclass: 'buttontbd',
          disabled: false
        }
        job[:actions] << {
          value: 'Queue Del',
          href: "#",
          cssclass: 'buttontbd',
          disabled: false
        }
        job[:actions] << {
          value: 'Hold',
          href: "#",
          cssclass: 'buttontbd',
          disabled: false
        }
        job[:actions] << {
          value: 'Release',
          href: "#",
          cssclass: 'buttontbd',
          disabled: false
        }
        table.add_row(
          AdminUI::Row.make_row(
            table.columns,
            job
          )
        )
      end
      table
    end

    def assembly_requests
      jobs = MerrittZK::Access.list_jobs_as_json(@zk)
      table = AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:id, header: 'ID'),
          AdminUI::Column.new(:token, header: 'Token'),
          AdminUI::Column.new(:bytes, header: 'Bytes GB', cssclass: 'float'),
          AdminUI::Column.new(:queue_status, header: 'Queue Status'),
          AdminUI::Column.new(:date, header: 'DateTime', cssclass: 'date'),
          AdminUI::Column.new(:actions, header: 'Actions'),
          AdminUI::Column.new(:status, header: 'Status'),
        ]
      )
      jobs.each do |job|
        job[:id] = {
          href: "/ops/zk/nodes/node-names?zkpath=#{job[:queueNode]}/#{job[:id]}&mode=data", 
          value: "#{job[:queueNode].gsub(/\/access\//, '')} #{job[:id]}"
        }
        job[:date] = date_format(job[:date])
        job[:bytes] = job[:bytes].to_f / 1_000_000_000
        job[:queue_status] = job[:status]
        job[:status] = 'PASS'
        job[:actions] = []
        job[:actions] << {
          value: 'Requeue',
          href: "#",
          cssclass: 'buttontbd',
          disabled: false
        }
        job[:actions] << {
          value: 'Queue Del',
          href: "#",
          cssclass: 'buttontbd',
          disabled: false
        }
        table.add_row(
          AdminUI::Row.make_row(
            table.columns,
            job
          )
        )
      end
      table
    end

    def dump_node_table(nodedump)
      table = AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:node, header: 'Node'),
          AdminUI::Column.new(:ref, header: 'Reference')
        ]
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

    def dump_node_data_table(nodedump)
      table = AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:node, header: 'Node'),
          AdminUI::Column.new(:nodedata, header: 'Node Data'),
          AdminUI::Column.new(:ref, header: 'Reference')
        ]
      )
      nodedump.each do |row|
        row.each do |node, value|
          next if node == "Status"
          table.add_row(
            AdminUI::Row.make_row(
              table.columns,
              {
                node: node,
                ref: make_ref(node).empty? ? make_ref(value) : make_ref(node),
                nodedata: JSON.pretty_generate(value)
              }
            )
          )
        end
      end
      table
    end  

    def dump_node_test_table(nodedump)
      table = AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:path, header: 'Path'),
          AdminUI::Column.new(:created, header: 'Created'),
          AdminUI::Column.new(:orphanpath, header: 'Orphan Path'),
          AdminUI::Column.new(:test, header: 'Test'),
          AdminUI::Column.new(:status, header: 'Status')
        ]
      )
      nodedump.each do |node|
        value = node.values.first
        next unless value.is_a?(Array)
        table.add_row(
          AdminUI::Row.make_row(
            table.columns,
            {
              path: value[0],
              created: value[1],
              orphanpath: value[2],
              test: value[3],
              status: value[4]
            }
          )
        )
      end
      table
    end

    def make_ref(node)
      return "" unless node.is_a?(String)

      m = /(bid[0-9]+)$/.match(node)
      return {href: "/ops/zk/nodes/node-names?zkpath=/batches/#{m[1]}&mode=data", value: "/batches/#{m[1]}"} if m
      m = /(jid[0-9]+)$/.match(node)
      return {href: "/ops/zk/nodes/node-names?zkpath=/jobs/#{m[1]}&mode=data", value: "/jobs/#{m[1]}"} if m
      m = /(qid[0-9]+)$/.match(node)
      return {href: "/ops/zk/nodes/node-names?zkpath=#{node}&mode=data", value: "#{m[1]}"} if m

      ""
    end

    def dump_nodes(params)
      nodedump = []
      nodedump = MerrittZK::NodeDump.new(@zk, params).listing unless @zk.nil?

      case params.fetch('mode', 'node')
      when 'data'
        table = dump_node_data_table(nodedump)
      when 'test'
        table = dump_node_test_table(nodedump)
      else 
        table = dump_node_table(nodedump)
      end
      table
    end
    attr_reader :zk

    def pause_ingest
      MerrittZK::Locks.lock_ingest_queue(@zk)
    end
  
    def unpause_ingest
      MerrittZK::Locks.unlock_ingest_queue(@zk)
    end

    def cleanup_ingest_queue
      MerrittZK::Batch.delete_completed_batches(@zk)
    end

    def pause_access_small
      MerrittZK::Locks.lock_small_access_queue(@zk)
    end
  
    def unpause_access_small
      MerrittZK::Locks.unlock_small_access_queue(@zk)
    end

    def pause_access_large
      MerrittZK::Locks.lock_large_access_queue(@zk)
    end
  
    def unpause_access_large
      MerrittZK::Locks.unlock_large_access_queue(@zk)
    end

    def cleanup_access_queue
      puts "Cleaning up access jobs"
      MerrittZK::Access.list_jobs_as_json(@zk).each do |job|
        qn = job.fetch(:queueNode, MerrittZK::Access::SMALL).gsub(%r{^/access/}, '')
        j = MerrittZK::Access.new(qn, job.fetch(:id, ''))
        j.load(@zk)
        next unless j.status.deletable?

        j.delete(@zk)
      end
    end
  end

end
