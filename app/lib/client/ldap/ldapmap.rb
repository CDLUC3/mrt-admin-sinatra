# frozen_string_literal: true

require_relative 'ldap'
require_relative '../query/query'

module UC3Ldap
  # map of ldap collection to collection
  class LDAPCollectionMapList
    def initialize(ldapcli)
      @colltable = UC3Query::QueryClient.client.query('/ops/collections/list', {})
      @ldapcli = ldapcli
      @ldapcoll = []
      if @ldapcli.enabled
        @ldapcli.load
        @ldapcoll = @ldapcli.collections_table_data
        @status = 'PASS'
      else
        puts 'LDAP Client not enabled'
        @status = 'ERROR'
      end
    rescue StandardError => e
      puts "LDAPCollectionMapList init error #{e}"
    end

    def ldap_collection_map(route)
      table = AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:ark, header: 'Ark'),
          AdminUI::Column.new(:mnemonic, header: 'Mnemonic'),
          AdminUI::Column.new(:description, header: 'Description'),
          AdminUI::Column.new(:coll, header: 'LDAP Coll'),
          AdminUI::Column.new(:status, header: 'Status', filterable: true)
        ],
        status: @status
      )
      map = {}
      @colltable.table_data.each do |row|
        m = row[:mnemonic]
        description = row[:collection_name]
        ark = row[:ark]
        next if ark.nil?
        next if m.to_s =~ /(_sla$|_service_level_agreement$|_curatorial_classes$|_system_classes$)/

        map[ark] = {
          ark: ark,
          mnemonic: m,
          description: description,
          coll: {
            value: 'Create LDAP Records (tbd)',
            href: '/ldap/create-collection-groups',
            data: {
              ark: ark,
              description: description,
              mnemonic: m
            }.to_json,
            cssclass: 'button',
            post: true,
            redirect: true,
            disabled: false
          },
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
            description: '',
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
      @ldapcli.record_status(route, table.status)
      table
    end
  end
end
