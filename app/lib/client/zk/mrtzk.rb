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

    def node_table
      AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:node, header: 'Node'),
          AdminUI::Column.new(:ref, header: 'Reference')
        ]
      )
    end  

    def node_data_table
      AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:node, header: 'Node'),
          AdminUI::Column.new(:ref, header: 'Reference'),
          AdminUI::Column.new(:nodedata, header: 'Node Data')
        ]
      )
    end  

    def node_test_table
      AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:path, header: 'Path'),
          AdminUI::Column.new(:created, header: 'Created'),
          AdminUI::Column.new(:orphanpath, header: 'Orphan Path'),
          AdminUI::Column.new(:test, header: 'Test'),
          AdminUI::Column.new(:status, header: 'Status')
        ]
      )
    end

    def dump_nodes(params)
      nodedump = []
      nodedump = MerrittZK::NodeDump.new(@zk, params) unless @zk.nil?

      case params.fetch('mode', 'node')
      when 'data'
        table = node_data_table
        nodedump.each do |node, value|
          table.add_row(
            AdminUI::Row.make_row(
              table.columns,
              {
                node: node,
                ref: '',
                nodedata: value
              }
            )
          )
        end
      when 'test'
        table = node_test_table
        nodedump.each do |value|
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
      else 
        table = node_table
        nodedump.each do |node|
          table.add_row(
            AdminUI::Row.make_row(
              table.columns,
              {
                node: node,
                ref: ''
              }
            )
          )
        end
      end
      table
    end
    attr_reader :zk
  end
end
