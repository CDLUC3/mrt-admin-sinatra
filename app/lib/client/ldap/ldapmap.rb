# frozen_string_literal: true

require_relative 'ldap'
require_relative '../query/query'

module UC3Ldap
  # map of ldap collection to collection
  class LDAPCollectionMapList
    def initialize
      @colltable = UC3Query::QueryClient.client.query('/queries/misc/collections', {})
      @ldap = UC3Ldap::LDAPClient.client
      @ldapcoll = []
      if @ldap.enabled
        @ldap.load
        @ldapcoll = @ldap.collections_table_data
        @status = 'PASS'
      else
        @status = 'ERROR'
      end
    end

    def ldap_collection_map(route)
      table = AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:ark, header: 'Ark'),
          AdminUI::Column.new(:mnemonic, header: 'Mnemonic'),
          AdminUI::Column.new(:coll, header: 'LDAP Coll'),
          AdminUI::Column.new(:status, header: 'Status')
        ],
        status: @status
      )
      map = {}
      @colltable.table_data.each do |row|
        m = row[:mnemonic]
        ark = row[:ark]
        next if ark.nil?

        map[ark] = {
          ark: ark,
          mnemonic: m,
          coll: '',
          status: 'FAIL'
        }
      end

      @ldapcoll.each do |coll|
        ark = coll[:arkid]
        m = coll[:mnemonic]
        next if ark.nil?
        next if m.nil?

        if map.key?(ark)
          map[ark][:status] = 'PASS'
          map[ark][:coll] = m
        else
          map[ark] = {
            ark: ark,
            coll: m,
            mnemonic: '',
            status: 'FAIL'
          }
        end
      end

      map.keys.sort.each do |ark|
        row = map[ark]
        table.add_row(
          AdminUI::Row.make_row(
            table.columns,
            row
          )
        )
      end
      @ldap.record_status(route, table.status)
      table
    end
  end
end
