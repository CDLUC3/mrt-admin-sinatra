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

    def date_format(date)
      return '' if date.nil? || date.empty?
      DateTime.parse(date).strftime('%Y-%m-%d %H:%M:%S')
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

    def jobs
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
  end
end
