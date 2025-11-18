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

      # use this to disable buttons in prd/stg if needed
      [UC3::UC3Client::ECS_DBSNAPSHOT].include?(stack_name)
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
          title: 'Download the XML *storage manifest* representation of a object on a specific storage node.' \
                 'This request will be forwarded to the storage service.',
          disabled: storage_mgt_disabled?(strict: true)
        }
        row['actions'] << {
          value: "Get Ingest Checkm (v#{row['version_number']})",
          href: "/ops/storage/ingest-checkm?node_number=#{row['node_number']}" \
                "&ark=#{row['ark']}&version_number=#{row['version_number']}",
          cssclass: 'button',
          title: 'Download an *ingest manifest checkm* representation of an object on a specific storage node. ' \
                 'This file could be utilized to re-ingest an object under a new ark.',
          disabled: storage_mgt_disabled?(strict: true)
        }
        row['actions'] << {
          value: 'Get Storage Manifest Yaml',
          href: "/ops/storage/manifest-yaml?node_number=#{row['node_number']}&ark=#{row['ark']}",
          cssclass: 'button',
          title: 'Download the XML *storage manifest* representation of a object on a specific storage node.  ' \
                 'This request will be forwarded to the storage service.  ' \
                 'The manifest xml file will be converted to a user-friendly yaml format.',
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

    def self.file_info_resolver(row)
      row['actions'] = []
      row['actions'] << {
        value: 'Fixity Benchmark',
        href: "/ops/storage/benchmark-fixity?inv_file_id=#{row['inv_file_id']}",
        cssclass: 'button',
        disabled: storage_mgt_disabled?(strict: true)
      }
      row
    end

    def self.collections_nodes_resolver(row)
      prim = UC3S3::ConfigObjectsClient.client.storage_node_for_mnemonic(row['mnemonic'])
      row['primary_node'] = prim

      row['actions'] = []
      row['actions'] << {
        value: 'Manage Nodes',
        href: "/ops/collections/storage-node-config/#{row['mnemonic']}_Storage_Nodes" \
              "?inv_collection_id=#{row['id']}&primary=#{prim}&mnemonic=#{row['mnemonic']}",
        cssclass: 'button',
        disabled: storage_mgt_disabled?(strict: true) || prim.empty?
      }
      row['status'] = 'FAIL' if prim.empty?
      row
    end

    def self.single_collection_nodes_resolver(row)
      row['pct_complete'] = row['total'].to_i.zero? ? 100.0 : 100.0 * row['count'].to_i / row['total'].to_i
      row['actions'] = []
      if row['role'] == 'secondary'
        row['actions'] << {
          value: 'Remove Secondary Node',
          href: "/queries-update/storage-nodes/delete?inv_collection_id=#{row['inv_collection_id']}" \
                "&node_number=#{row['node_number']}",
          cssclass: 'button',
          post: true,
          disabled: storage_mgt_disabled?
        }
      end

      if row['role'] == 'obsolete'
        row['actions'] << {
          value: 'Start Deletion Process',
          title: 'Initiate a process to delete data from this node.  Deletions will occur in batches of 50.',
          href: "/ops/storage-nodes/remove-obsolete?inv_collection_id=#{row['inv_collection_id']}" \
                "&node_number=#{row['node_number']}",
          cssclass: 'button button_red',
          post: true,
          disabled: storage_mgt_disabled?
        }
      end
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
      if row['acount'].positive?
        row['acount'] = {
          value: row['acount'],
          href: "/ops/db-queue/audit/counts-by-state/objlist?status=#{row['astatus']}"
        }
      end
      row
    end

    def self.storage_scan_resolver(row)
      row['nodedesc'] = [
        row['node_number'],
        row['description'],
        row['access_mode'],
        "Count: #{row['pcount']}"
      ]

      row['actions'] = []
      row['actions'] << {
        value: 'Scan History',
        href: "/ops/storage/scans/history?node_number=#{row['node_number']}",
        cssclass: 'button'
      }
      status = row.fetch('scan_status', '')
      status = '' if status.nil?
      node = row.fetch('node_number', 0).to_i
      if %w[completed cancelled].include?(status) || status.empty?
        unless [9501, 9502].include?(node)
          row['actions'] << {
            value: 'Start Scan',
            href: "/ops/storage/scans/start?node_number=#{node}",
            cssclass: 'button',
            post: true,
            disabled: storage_mgt_disabled?(strict: true)
          }
        end

        if [9501, 9502, 7777].include?(node)
          keylist = if node == 7777
                      '8888:scanlist/7777.log'
                    else
                      "7001:scanlist/#{node}.log"
                    end
          row['actions'] << {
            value: 'Start Scan Keylist',
            href: "/ops/storage/scans/start?node_number=#{node}&keylist=#{keylist}",
            title: "Start a scan using the scanlist file in cloud storage #{keylist}",
            cssclass: 'button',
            post: true,
            disabled: storage_mgt_disabled?(strict: true)
          }
        end
        row['percent_complete'] = ''
      end
      if %w[pending].include?(status)
        row['actions'] << {
          value: 'Resume Scan',
          href: "/ops/storage/scans/resume?inv_scan_id=#{row['inv_scan_id']}",
          cssclass: 'button',
          post: true,
          disabled: storage_mgt_disabled?(strict: true)
        }
      end
      if %w[pending started].include?(status)
        row['actions'] << {
          value: 'Cancel Scan',
          href: "/ops/storage/scans/cancel?inv_scan_id=#{row['inv_scan_id']}",
          cssclass: 'button',
          post: true,
          disabled: storage_mgt_disabled?(strict: true)
        }
      end
      if row.fetch('num_review', 0).positive?
        row['num_review'] = {
          value: row['num_review'],
          href: "/ops/storage/scans/review-state?node_number=#{node}&status=review"
        }
      end
      if row.fetch('num_hold', 0).positive?
        row['num_hold'] = {
          value: row['num_hold'],
          href: "/ops/storage/scans/review-state?node_number=#{node}&status=hold"
        }
      end
      if row.fetch('num_deletes', 0).positive?
        row['num_deletes'] = {
          value: row['num_deletes'],
          href: "/ops/storage/scans/review-state?node_number=#{node}&status=delete"
        }
      end
      if row.fetch('num_maints', 0).positive?
        row['num_maints'] = {
          value: row['num_maints'],
          href: "/ops/storage/scans/review?node_number=#{node}"
        }
      end
      row
    end

    def self.storage_scan_review_resolver(row)
      row['s3key_annotated'] = [
        row['s3key'],
        "Node: #{row['node_number']}",
        row['file_created'],
        "Size: #{row['size']}"
      ]
      if row['inv_object_id']
        row['s3key_annotated'] << {
          value: row['inv_object_id'],
          href: "/queries/repository/object?inv_object_id=#{row['inv_object_id']}"
        }
      end
      row['note'] = [
        "Type: #{row['maint_type']}",
        "Status: #{row['maint_status']}",
        "Note: #{row['note']}"
      ]
      row['actions'] = []
      if row['maint_status'] != 'delete'
        row['actions'] << {
          value: 'Mark for Delete',
          href: "/queries-update/storage-maints/update-status?maint_id=#{row['maint_id']}&status=delete",
          post: true,
          cssclass: 'button',
          disabled: storage_mgt_disabled?(strict: true)
        }
      end
      if row['maint_status'] != 'review'
        row['actions'] << {
          value: 'Mark for Review',
          href: "/queries-update/storage-maints/update-status?maint_id=#{row['maint_id']}&status=review",
          post: true,
          cssclass: 'button',
          disabled: storage_mgt_disabled?(strict: true)
        }
      end
      if row['maint_status'] != 'hold'
        row['actions'] << {
          value: 'Mark for Hold',
          href: "/queries-update/storage-maints/update-status?maint_id=#{row['maint_id']}&status=hold",
          post: true,
          cssclass: 'button',
          disabled: storage_mgt_disabled?(strict: true)
        }
      end
      if row['maint_status'] == 'delete'
        row['actions'] << {
          value: 'Process Delete',
          href: "/ops/storage/scans/delete?maint_id=#{row['maint_id']}",
          post: true,
          cssclass: 'button button_red',
          disabled: storage_mgt_disabled?
        }
      end
      row
    end

    def self.storage_scan_csv_resolver(row)
      arr = row.fetch('s3key', '').split('|')
      row['key_ark'] = arr[0]
      row['key_ver'] = arr[1]
      m = %r{^(producer|system)/(.*)$}.match(arr[2])
      if m
        row['key_folder'] = m[1]
        row['key_file'] = m[2]
      else
        row['key_file'] = arr[2]
      end
      row
    end

    def self.collections_resolver(row)
      begin
        return row unless UC3Queue::ZKClient.client.enabled

        locked_coll = UC3Queue::ZKClient.client.locked_collections
        row['locked'] = locked_coll.fetch("#{row['mnemonic']}_content", false)
        row['actions'] = []

        unless row['locked']
          row['actions'] << {
            value: 'Lock Collection',
            href: "/ops/zk/collection/lock?mnemonic=#{row['mnemonic']}_content",
            post: true,
            cssclass: 'button'
          }
        end

        if row['locked']
          row['actions'] << {
            value: 'Unlock Collection',
            href: "/ops/zk/collection/unlock?mnemonic=#{row['mnemonic']}_content",
            post: true,
            cssclass: 'button'
          }
        end
      rescue StandardError
        # handle zk errors silently
      end
      row
    end
  end
end
