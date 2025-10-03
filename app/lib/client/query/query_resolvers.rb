# frozen_string_literal: true

# Query module
module UC3Query
  # Resolve special query columns in table displays
  class QueryResolvers
    def self.default_resolver(row)
      row
    end

    def self.storage_mgt_disabled?(strict: false)
      stack_name = UC3::UC3Client.stack_name
      return [UC3::UC3Client::ECS_DBSNAPSHOT].include?(stack_name) if strict

      [UC3::UC3Client::ECS_DBSNAPSHOT, UC3::UC3Client::ECS_PRD].include?(stack_name)
    end

    def self.obj_info_resolver(row)
      row['metadata'] = []
      row['metadata'] << "What: #{row['erc_what']}"
      row['metadata'] << "Who: #{row['erc_who']}"
      row['metadata'] << "When: #{row['erc_when']}"
      row['metadata'] << "Own: #{row['name']}"

      row['actions'] = []
      row['actions'] << {
        value: 'Trigger Replication',
        href: "/queries-update/replic/trigger?inv_object_id=#{row['inv_object_id']}",
        cssclass: 'button',
        post: true,
        disabled: storage_mgt_disabled?(strict: true)
      }
      row
    end

    def self.obj_node_resolver(row)
      pstr = "?inv_object_id=#{row['inv_object_id']}&inv_node_id=#{row['node_id']}"
      row['description'] = [row['node_number'], row['description'], row['acceess_mode']]
      row['actions'] = []
      row['actions'] << {
        value: 'Re-audit All Files',
        href: "/queries-update/audit/reset#{pstr}",
        cssclass: 'button',
        post: true,
        disabled: storage_mgt_disabled?(strict: true)
      }
      row['actions'] << {
        value: 'Re-audit Unverified',
        href: "/queries-update/audit/reset-unverified#{pstr}",
        cssclass: 'button',
        post: true,
        disabled: storage_mgt_disabled?(strict: true)
      }
      if row['role'] == 'primary'
        row['actions'] << {
          value: 'Get Manifest',
          href: "/ops/storage/manifest?node_number=#{row['node_number']}&ark=#{row['ark']}",
          cssclass: 'button',
          disabled: storage_mgt_disabled?(strict: true)
        }
        row['actions'] << {
          value: "Get Ingest Checkm (v#{row['version_number']})",
          href: "/ops/storage/ingest-checkm?node_number=#{row['node_number']}" \
                "&ark=#{row['ark']}&version_number=#{row['version_number']}",
          cssclass: 'button',
          disabled: storage_mgt_disabled?(strict: true)
        }
        row['actions'] << {
          value: 'Get Storage Manifest Yaml',
          href: "/ops/storage/manifest-yaml?node_number=#{row['node_number']}&ark=#{row['ark']}",
          cssclass: 'button',
          disabled: storage_mgt_disabled?(strict: true)
        }
        row['actions'] << {
          value: 'Rebuild Inventory',
          href: "/ops/inventory/rebuild?node_number=#{row['node_number']}&ark=#{row['ark']}",
          cssclass: 'button button_red',
          confmsg: %(Are you sure you want to rebuild the INV entry for this ark?
            A new inv_object_id will be assigned.),
          post: true,
          disabled: storage_mgt_disabled?(strict: true)
        }
        row['actions'] << {
          value: 'Clear Scan Entries for Ark',
          href: "/queries-update/storage-maints/clear-entries-for-ark?ark=#{row['ark']}",
          cssclass: 'button',
          post: true,
          disabled: storage_mgt_disabled?(strict: true)
        }
      end
      row
    end

    def self.collection_nodes_resolver(row)
      prim = UC3S3::ConfigObjectsClient.client.storage_node_for_mnemonic(row['mnemonic'])
      row['primary_node'] = prim

      row['actions'] = []
      row['actions'] << {
        value: 'Manage Nodes',
        href: '/ops/collections/storage-node-config/collection' \
              "?inv_collection_id=#{row['id']}&primary=#{prim}",
        cssclass: 'button',
        disabled: storage_mgt_disabled?(strict: true) || prim.empty?
      }
      row['status'] = 'FAIL' if prim.empty?
      row
    end

    def self.audit_status_resolver(row)
      row['actions'] = []
      if row['acount'].positive? && !%w[processing unknown].include?(row['astatus'])
        row['actions'] << {
          value: 'Re-try Audit',
          href: "/queries-update/audit/status-reset?status=#{row['astatus']}",
          post: true,
          cssclass: 'button',
          disabled: storage_mgt_disabled?
        }
      end
      row
    end

    def self.storage_scan_resolver(row)
      row
    end
  end
end
