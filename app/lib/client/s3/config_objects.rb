# frozen_string_literal: true

require 'aws-sdk-s3'
require_relative '../uc3_client'

# Scope custom code for UC3 to distinguish from 3rd party classes
module UC3S3
  # Query for repository images by tag
  class ConfigObjectsClient < UC3::UC3Client
    MAX_DELETE_DETAILS = 25

    def self.client
      UC3::UC3Client.clients.fetch(self.class.to_s, ConfigObjectsClient.new)
    end

    def initialize
      opt = {}
      opt[:region] = 'us-west-2'
      unless ENV.fetch('S3ENDPOINT', '').empty?
        opt[:endpoint] = ENV.fetch('S3ENDPOINT', '')
        opt[:credentials] = Aws::Credentials.new(
          ENV.fetch('S3ACCESSKEY', ''),
          ENV.fetch('S3SECRETKEY', '')
        )
        opt[:force_path_style] = true unless ENV.fetch('S3ENDPOINT', '').empty?
        # minio defaults to us-east-1
        opt[:region] = ENV.fetch('S3REGION', 'us-east-1')
      end

      @config_objects = {}
      begin
        @s3_client = Aws::S3::Client.new(opt)
        @s3_presigner = Aws::S3::Presigner.new(client: @s3_client)
        @prefix = ENV.fetch('S3CONFIG_PREFIX', 'uc3/mrt/mrt-ingest-profiles/')
        @bucket = ENV.fetch('S3CONFIG_BUCKET', 'mrt-config')
        @report_bucket = ENV.fetch('S3REPORT_BUCKET', 'mrt-reports')

        resp = @s3_client.get_object(
          bucket: @bucket,
          key: "#{@prefix}index.yaml"
        )
        @config_objects = YAML.safe_load(resp.body.read, symbolize_names: true)
      rescue StandardError => e
        # puts e
        raise "Unable to load configuration data from S3: #{e}"
      end

      @ezidconf = UC3::UC3Client.lookup_map_by_filename(
        'app/config/mrt/ezid.lookup.yml',
        key: ENV.fetch('configkey', 'default'),
        symbolize_names: true
      )
      super(enabled: !@config_objects.empty?)
    rescue StandardError => e
      # puts e
      super(enabled: false, message: e.to_s)
    end

    def enabled
      !@config_objects.empty?
    end

    def notification_map
      @config_objects.each_with_object({}) do |(key, value), map|
        map[key] = value[:Notification] if value[:Notification]
      end
    end

    def storage_node_for_mnemonic(mnemonic)
      key = :"#{mnemonic}_content"
      @config_objects.fetch(key, {}).fetch(:StorageNode, '')
    end

    def list_profiles
      table = AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:key, header: 'Profile Link'),
          AdminUI::Column.new(:Match, header: 'ProfileId Matches'),
          AdminUI::Column.new(:Owner, header: 'Owner'),
          AdminUI::Column.new(:StorageNode, header: 'StorageNode'),
          AdminUI::Column.new(:Priority, header: 'Priority'),
          AdminUI::Column.new(:ProfileDescription, header: 'ProfileDescription'),
          AdminUI::Column.new(:CallbackURL, header: 'CallbackURL'),
          AdminUI::Column.new(:error, header: 'Error')
        ]
      )
      return table unless enabled

      @config_objects.each do |key, value|
        value[:key] = {
          value: key,
          href: "/ops/collections/management/profiles/#{key}"
        }
        table.add_row(AdminUI::Row.make_row(table.columns, value))
      end
      table
    end

    def get_profile(profile)
      resp = @s3_client.get_object(
        bucket: @bucket,
        key: "#{@prefix}#{profile}"
      )
      resp.body.read
    rescue StandardError => e
      e.to_s
    end

    def make_profile(params, ark: 'ark:/13030/mintme')
      resp = @s3_client.get_object(
        bucket: @bucket,
        key: "#{@prefix}TEMPLATE-PROFILE"
      )
      profile = resp.body.read
      profile.gsub!('${ARK}', ark)
      profile.gsub!('${NAME}', "#{params.fetch('name', '')}_content")
      profile.gsub!('${CONTEXT}', params.fetch('name', ''))
      profile.gsub!('${COLLECTION}', ark)
      profile.gsub!('${DESCRIPTION}', params.fetch('description', ''))
      profile.gsub!('${OWNER}', params.fetch('owner', ''))
      notsub = ''
      params.fetch('notifications', '').split(',').each_with_index do |n, i|
        notsub += "Notification.#{i + 1}: #{n.strip}\n"
      end
      profile.gsub!(/^Notification\..*$/, notsub.strip)
      now = Time.now.strftime('%Y-%m-%dT%H:%M:%S%z')
      profile.gsub!('${CREATIONDATE}', now)
      profile.gsub!('${MODIFICATIONDATE}', now)
      profile.gsub!('${STORAGENODE}', params.fetch('primarynode', ''))
      profile
    rescue StandardError => e
      e.to_s
    end

    def mint_sla_url
      "#{@ezidconf.fetch(:api, 'http://ezid:4567')}/shoulder/#{@ezidconf.fetch(:sla_shoulder, 'ark:/99999/fk4')}"
    end

    def create_sla(params)
      ark = mint(mint_sla_url, params.fetch('name', ''))
      puts "SLA Ark Minted: #{ark}"
      add_sla(ark, params.fetch('name', ''), params.fetch('mnemonic', ''))
      ark
    end

    def mint_owner_url
      "#{@ezidconf.fetch(:api, 'http://ezid:4567')}/shoulder/#{@ezidconf.fetch(:owner_shoulder, 'ark:/99999/fk4')}"
    end

    def create_owner(params)
      ark = mint(mint_owner_url, params.fetch('name', ''))
      puts "Owner Ark Minted: #{ark}"
      add_owner(ark, params.fetch('name', ''), params.fetch('sla', ''))
      ark
    end

    def mint_collection_url
      "#{@ezidconf.fetch(:api, 'http://ezid:4567')}/shoulder/#{@ezidconf.fetch(:collection_shoulder, 'ark:/99999/fk4')}"
    end

    def mint(url, description)
      raise 'Minting not supported' unless @ezidconf.fetch(:supported, true)

      # https://ezid.cdlib.org/doc/apidoc.html#internal-metadata
      body = []
      body << "_target: #{@ezidconf.fetch(:target, '')}"
      body << '_owner: merritt'
      body << '_profile: erc'
      body << '_status: reserved'
      body << '_export: no'
      body << "what: #{description}"

      r = post_url_body(
        url,
        body: body.join("\n"),
        user: @ezidconf.fetch(:user, nil),
        password: @ezidconf.fetch(:password, nil)
      )
      m = /^([^:]*): (.*)$/.match(r)
      raise "Mint failure: #{r}" unless m
      raise "Mint failure: #{r}" unless m[1] == 'success'

      m[2]
    end

    def create_collection(params)
      ark = mint(mint_collection_url, params.fetch('description', ''))
      puts "Collection Ark Minted: #{ark}"
      add_collection(ark, params.fetch('description', ''), params.fetch('name', ''), public: params.key?('public'))
      # add ldap stuff
      ark
    end

    def add_collection(ark, name, mnemonic, public: false)
      vis = public ? 'public' : 'private'
      post_url_multipart(
        "#{inventory_host}/admin/collection/#{vis}",
        { adminid: ark, name: name, mnemonic: mnemonic }
      )
    end

    def add_owner(ark, name, sla_ark)
      post_url_multipart(
        "#{inventory_host}/admin/owner",
        { adminid: ark, name: name, slaid: sla_ark }
      )
    end

    def add_sla(ark, name, mnemonic)
      post_url_multipart(
        "#{inventory_host}/admin/sla",
        { adminid: ark, name: name, mnemonic: mnemonic }
      )
    end

    def create_report(path, body, content_type: nil)
      arg = {
        body: body,
        bucket: @report_bucket,
        key: path
      }
      arg[:content_type] = content_type unless content_type.nil?
      @s3_client.put_object(arg)
    end

    def get_report(path)
      url, = @s3_presigner.presigned_request(
        :get_object,
        bucket: @report_bucket,
        key: path,
        expires_in: 604_800 # 7 days which is max allowed by AWS
      )
      url
    end

    def get_doc_page(doc)
      key = "uc3/mrt/mrt-admin-sinatra/docs/#{UC3::UC3Client.stack_name}/#{doc}"
      @s3_client.get_object(
        bucket: @bucket,
        key: key
      ).body.read
    rescue StandardError
      ''
    end

    def get_report_url(path)
      table = AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:url, header: 'URL')
        ]
      )
      table.add_row(AdminUI::Row.make_row(table.columns, { url: get_report(path) }))
      table
    end

    def list_reports(path)
      table = AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:path, header: 'Report Path'),
          AdminUI::Column.new(:download, header: 'Download'),
          AdminUI::Column.new(:url, header: 'URL'),
          AdminUI::Column.new(:created, header: 'Created'),
          AdminUI::Column.new(:size, header: 'Size')
        ]
      )
      resp = @s3_client.list_objects_v2({
        bucket: @report_bucket,
        prefix: path
      })
      resp.contents.each do |s3obj|
        row = {
          path: s3obj.key,
          download: {
            href: "/saved-reports/retrieve?report=#{URI.encode_www_form_component(s3obj.key)}",
            value: 'Download'
          },
          url: {
            href: "/saved-reports/url?report=#{URI.encode_www_form_component(s3obj.key)}",
            value: 'URL'
          },
          created: s3obj.last_modified,
          size: s3obj.size
        }
        table.add_row(AdminUI::Row.make_row(table.columns, row))
      end
      table
    end

    def get_ecs_release_manifest
      resp = @s3_client.get_object(
        bucket: @bucket,
        key: 'uc3/mrt/mrt-ecs-manifest/ecs-release-manifest.yaml'
      )
      YAML.safe_load(resp.body.read)
    rescue StandardError => e
      puts "Error retrieving ECS release manifest: #{e}"
      { manifest: 'Not Found' }
    end

    def get_ec2_release_manifest
      resp = @s3_client.get_object(
        bucket: @bucket,
        key: 'uc3/mrt/mrt-ecs-manifest/service-release-manifest.yaml'
      )
      YAML.safe_load(resp.body.read)
    rescue StandardError => e
      puts "Error retrieving ECS release manifest: #{e}"
      { manifest: 'Not Found' }
    end

    def get_ecs_release_manifest_deploy_tags(reposhort)
      tags = []
      tagmap = get_ecs_release_manifest.fetch('ecs-tagmap', {})
      tagmap.fetch(reposhort, {}).each_value do |tag|
        tags << tag
      end
      tags.uniq
    end

    def get_ec2_release_manifest_deploy_tags(reposhort)
      tags = []
      %w[prd stg].each do |env|
        tag = get_ec2_release_manifest.fetch("uc3-#{reposhort}-#{env}", '')
        tags << tag unless tag.empty?
      end
      tags.uniq
    end

    def get_release_manifest_deploy_tags(reposhort)
      tags = get_ecs_release_manifest_deploy_tags(reposhort) + get_ec2_release_manifest_deploy_tags(reposhort)
      tags.uniq
    end

    def get_delete_lists
      prefix = "uc3/mrt/mrt-object-delete-files/#{UC3::UC3Client.stack_name_brief}/"
      resp = @s3_client.list_objects_v2({
        bucket: @bucket,
        prefix: prefix
      })
      data = []
      resp.contents.each do |s3obj|
        body = @s3_client.get_object({
          bucket: @bucket,
          key: s3obj.key
        }).body.read
        doc = YAML.safe_load(body, symbolize_names: true, permitted_classes: [Date])
        path = s3obj.key.gsub(/^#{prefix}/, '')
        next if doc.fetch(:completed, true)

        next unless doc.fetch(:stack, '') == UC3::UC3Client.stack_name
        
        data << {
          path: path,
          reason: doc.fetch(:reason, 'N/A'),
          date: doc.fetch(:date, 'N/A'),
          count: doc.fetch(:objects, []).size,
          review: { href: "delete-lists/#{URI.encode_www_form_component(path)}", value: 'Review' },
          json: { href: "delete-list/#{URI.encode_www_form_component(path)}", value: 'JSON' }
        }
      end
      data
    end

    def list_delete_lists
      paths = []
      get_delete_lists.each do |row|
        paths << row[:path]
      end
      paths
    end

    def review_delete_lists
      table = AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:path, header: 'File Path'),
          AdminUI::Column.new(:reason, header: 'Reason'),
          AdminUI::Column.new(:date, header: 'Date'),
          AdminUI::Column.new(:count, header: 'Count'),
          AdminUI::Column.new(:review, header: 'Review'),
          AdminUI::Column.new(:json, header: 'JSON')
        ],
        description:
          'This page lists the ' \
          '[delete lists](https://github.com/CDLUC3/mrt-doc-private/tree/main/object-delete-files) ' \
          'that have been generated for this stack ([Simple List](/ops/inventory/list-delete-lists)).' \
          "\n\nThese lists are published to an S3 bucket for processing." \
          "\n\nTo process a delete list, use the following command in a merritt-ops session for this stack:" \
          "\n\n[Create a merritt-ops session for this stack](/#create-ops)" \
          "\n\n```" \
          "\n/run-delete-list.sh <<file path>>" \
          "\n```"
      )

      get_delete_lists.each do |row|
        table.add_row(AdminUI::Row.make_row(table.columns, row))
      end
      table
    end

    def get_delete_list(list_name)
      arks = []
      body = @s3_client.get_object({
        bucket: @bucket,
        key: "uc3/mrt/mrt-object-delete-files/#{UC3::UC3Client.stack_name_brief}/#{list_name}"
      }).body.read
      doc = YAML.safe_load(body, symbolize_names: true, permitted_classes: [Date])

      return { message: 'Delete list iscompleted' } if doc.fetch(:completed, true)

      unless doc.fetch(:stack, '') == UC3::UC3Client.stack_name
        return { message: "Delete list is for stack #{doc.fetch(:stack, '')}" }
      end

      doc.fetch(:objects, []).each do |ark|
        arks << ark
      end
      arks
    end

    def review_delete_list(list_name)
      arks = get_delete_list(list_name)

      cols = []
      cols << AdminUI::Column.new(:ark, header: 'Ark')
      if arks.size <= MAX_DELETE_DETAILS
        cols << AdminUI::Column.new(:mnemonics, header: 'Mnemonics')
        cols << AdminUI::Column.new(:created, header: 'Created')
        cols << AdminUI::Column.new(:erc_what, header: 'ERC What')
        cols << AdminUI::Column.new(:billable_size, header: 'Billable Size')
        cols << AdminUI::Column.new(:file_count, header: 'File Count')
      end

      table = AdminUI::FilterTable.new(
        columns: cols,
        description:
          "This page lists the objects in the delete list: `#{list_name}`" \
          "\n\nIf the delete list has more than #{MAX_DELETE_DETAILS} objects, only the ark will be returned." \
          "\n\nTo process this delete list, use the following command in a merritt-ops session for this stack:" \
          "\n\n[Create a merritt-ops session for this stack](/#create-ops)" \
          "\n\n```" \
          "\n/run-delete-list.sh #{list_name}" \
          "\n```"
      )

      return table unless arks.is_a?(Array)

      arks.each do |ark|
        row = {
          ark: {
            href: "/queries/repository/object-ark?ark=#{CGI.escape(ark)}",
            value: ark
          }
        }
        if arks.size <= MAX_DELETE_DETAILS
          urlparams = {}
          urlparams['ark'] = ark
          UC3Query::QueryClient.client.run_query('/queries/repository/object-ark',
            urlparams).each do |result|
            row[:mnemonics] = result.fetch('mnemonics', '')
            row[:created] = result.fetch('created', '')
            row[:erc_what] = result.fetch('erc_what', '')
            row[:billable_size] = result.fetch('billable_size', '0').to_i
            row[:file_count] = result.fetch('file_count', '0').to_i
          end
        end
        table.add_row(AdminUI::Row.make_row(table.columns, row))
      end
      table
    end
  end
end
