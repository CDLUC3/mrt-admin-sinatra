# frozen_string_literal: true

require 'aws-sdk-s3'
require_relative '../uc3_client'

# Scope custom code for UC3 to distinguish from 3rd party classes
module UC3S3
  # Query for repository images by tag
  class ConfigObjectsClient < UC3::UC3Client
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
      now = Time.now.utc.strftime('%Y-%m-%dT%H:%M:%S-%Z')
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
  end
end
