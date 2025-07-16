# frozen_string_literal: true

require 'aws-sdk-ssm'
require 'mustache'
require 'yaml'
require_relative '../ui/table'

# Scope custom code for UC3 to distinguish from 3rd party classes
module UC3
  # Base class for UC3 client classes
  class UC3Client
    STATUS = %i[SKIP PASS INFO WARN FAIL ERROR].freeze
    STATHASH = {
      SKIP: 0,
      PASS: 1,
      INFO: 2,
      WARN: 3,
      FAIL: 4,
      ERROR: 5
    }.freeze

    @clients = {}

    def self.client
      UC3::UC3Client.clients.fetch(self.class.to_s, UC3Client.new)
    end

    def initialize(enabled: true, message: '')
      UC3Client.clients[self.class.to_s] = { name: self.class.to_s, enabled: enabled, message: message }
    end

    def self.status_index(stat)
      STATHASH.fetch(stat.to_sym, 0)
    end

    def self.status_resolve(stat)
      STATUS[status_index(stat)]
    end

    def self.status_compare(stat1, stat2)
      status_index(stat1) > status_index(stat2) ? stat1 : stat2
    end

    def record_status(path, status)
      qc = UC3Query::QueryClient.client
      if !qc.nil? && qc.enabled
        begin
          sql = %{
              insert into daily_consistency_checks(check_name, status)
              values(?, ?)
            }
          qc.run_sql(sql, [path, status.to_s])
        rescue StandardError => e
          puts "Error recording status for #{path}: #{e.message}"
        end
        return
      end
      puts "Status for #{path} is #{status}"
    end

    def date_format(date, convert_timezone: false)
      return '' if date.nil? || date.to_s.empty?

      d = DateTime.parse(date.to_s).to_time
      return '' if d.nil?

      d = d.localtime if convert_timezone
      d.strftime('%Y-%m-%d %H:%M:%S')
    end

    def self.region
      ENV['AWS_REGION'] || 'us-west-2'
    end

    def enabled
      false
    end

    def context
      table = AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:key, header: 'Key'),
          AdminUI::Column.new(:value, header: 'Value')
        ]
      )
      ENV.sort.each do |key, value|
        v = key =~ /(KEY|TOKEN|SECRET)/ ? '***' : value
        table.add_row(AdminUI::Row.new([key, v]))
      end
      table
    end

    class << self
      attr_reader :clients
    end

    def client_list
      table = AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:name, header: 'Client'),
          AdminUI::Column.new(:enabled, header: 'Enabled'),
          AdminUI::Column.new(:message, header: 'Message')
        ]
      )
      self.class.clients.sort.each do |_key, value|
        table.add_row(AdminUI::Row.make_row(table.columns, value))
      end
      table
    end

    def self.load_config(filename)
      config = YAML.safe_load_file(filename, aliases: true)
      JSON.parse(config.to_json, symbolize_names: true)
    end

    def self.lookup_map_by_filename(filename)
      map = YAML.safe_load_file(filename, aliases: true)
      lookup_map(map)
    end

    def self.lookup_map(map)
      ssm = Aws::SSM::Client.new(
        region: UC3::UC3Client.region
      )
      map.each do |key, value|
        if value.key?('ssm') && !ssm.nil?
          begin
            resp = ssm.get_parameter(name: value['ssm'], with_decryption: true)
            map[key] = resp.parameter.value
          rescue StandardError
            map[key] = value.fetch('default', 'not-applicable')
          end
        elsif value.key?('env')
          map[key] = ENV.fetch(value['env'], value.fetch('default', ''))
        elsif value.key?('val')
          map[key] = value['val']
        end

        case value.fetch('type', 'string')
        when 'int'
          map[key] = map[key].to_i
        when 'float'
          map[key] = map[key].to_f
        end
      end
      map
    end

    def self.resolve_lookup(filename, map)
      YAML.safe_load(Mustache.render(File.read(filename), map))
    end

    def self.semantic_tag?(tag)
      !(tag =~ /^\d+\.\d+\.\d+$/).nil?
    end

    def self.semantic_prefix_tag?(tag)
      !(tag =~ /^\d+\.\d+\.\d+(\..+)?$/).nil?
    end

    def self.deployed_tag?(tag, itags)
      arr = itags.clone
      arr << tag
      arr.each do |t|
        return true if t =~ /^(ecs-.*|dev|stg|prd|latest)$/
      end
      false
    end

    def self.keep_artifact_version?(ver)
      ver =~ /^\d+\.\d+-SNAPSHOT$/
    end
  end

  # browse ingest folder file system
  class FileSystemClient < UC3Client
    DIR = '/tdr/ingest/queue'
    def ingest_folders(route, params)
      path = params.fetch('path', '')
      path = '' if path =~ /^\.\./
      dir = path.empty? ? DIR : "#{DIR}/#{path}"

      table = AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:name, header: 'Name'),
          AdminUI::Column.new(:created, header: 'Created'),
          AdminUI::Column.new(:size, header: 'Bytes', cssclass: 'size'),
          AdminUI::Column.new(:actions, header: 'Actions')
        ],
        status: 'PASS'
      )
      count = 0
      Dir.entries(dir).sort.each do |folder|
        next if folder == '.' || (folder == '..' && path.empty?)

        count += 1
        break if count > 1000

        data = if File.directory?("#{dir}/#{folder}")
                 if folder == '..'
                   {
                     name: { value: '..', href: "/ops/zk/ingest/folders?path=#{File.dirname(path)}" },
                     created: '',
                     size: '',
                     actions: []
                   }
                 else
                   {
                     name: { value: folder, href: "/ops/zk/ingest/folders?path=#{path}/#{folder}" },
                     created: date_format(File.ctime("#{dir}/#{folder}")),
                     size: '',
                     actions: []
                   }
                 end
               elsif folder =~ /(Estimate|Provision|Download|Process|Notify)_FAIL$/
                 {
                   name: folder,
                   created: date_format(File.ctime("#{dir}/#{folder}")),
                   size: File.size("#{dir}/#{folder}"),
                   actions: {
                     value: 'Delete',
                     href: '/ops/zk/ingest/folder/delete',
                     data: folder,
                     cssclass: 'button',
                     post: true,
                     disabled: false
                   }
                 }
               else
                 {
                   name: folder,
                   created: date_format(File.ctime("#{dir}/#{folder}")),
                   size: File.size("#{dir}/#{folder}"),
                   actions: []
                 }
               end
        table.add_row(AdminUI::Row.make_row(
          table.columns,
          data
        ))
      end
      record_status(route, table.status)
      table
    end

    def self.client
      UC3::UC3Client.clients.fetch(self.class.to_s, FileSystemClient.new)
    end

    def cleanup_ingest_folders
      `find #{DIR} -maxdepth 1  -name "bid-*" -mtime +30 | xargs rm -rf`
      `find #{DIR}/FAILED -maxdepth 1  -name "bid-*" -mtime +30 | xargs rm -rf`
      `find #{DIR}/RecycleBin -maxdepth 1  -name "jid-*" -mtime +3 | xargs rm -rf`
      `find #{DIR}/zk-snapshots -maxdepth 1  -name "latest-snapshot.20-*" -mtime +3 | xargs rm -rf`
    end
  end

  # Identify routes for Consistency Checks and for Unit Testing
  class TestClient < UC3Client
    def initialize
      super(enabled: true, message: 'Test Client')

      @test_paths = []
      @consistency_checks = []

      UC3Query::QueryClient.client.queries.each_key do |name|
        name = name.to_s
        %w[
          /queries/consistency/.*/
          /ops/collections/db/
          /ops/db-queue/audit/counts-by-state
          /ops/db-queue/audit/oldest-audit-check
          /ops/db-queue/audit/30-days
          /ops/db-queue/audit/active-batches
          /ops/db-queue/audit/new-ucb-content
          /ops/db-queue-update/audit/reset-new-ucb-content
          /ops/db-queue/replication/failed
          /ops/db-queue/replication/in-progress
          /ops/db-queue/replication/required
          /ops/storage/db/nodes
        ].each do |pattern|
          next if name =~ %r{/objlist}

          @consistency_checks << name if name =~ /#{pattern}/
        end
        @test_paths << name unless @consistency_checks.include?(name)
      end

      Sinatra::Application.routes['GET'].each do |path, route|
        # .each_keys does not work, so make use of route object
        puts "Route #{path}: #{route.inspect}" unless route.empty?
        path = path.to_s
        next if path.include? '**'
        next if path.include? '*/*'

        if path.include? '*'
          if path.start_with?('/source/')
            UC3Code::SourceCodeClient.client.reponames.each do |repo|
              @test_paths << path.gsub('*', repo.to_s)
            end
          end
        else
          @test_paths << path
          # TODO: SSM documentation
          %w[
            /ldap/collections-missing
            /ops/zk/access/jobs
            /ops/zk/ingest/jobs-by-collection
            /ops/zk/ingest/batches
            /ops/zk/nodes/orphan
            /ops/zk/ingest/folders
          ].each do |pattern|
            @consistency_checks << path if path =~ /#{pattern}/
          end
        end
      end
      @test_paths.sort!
      @consistency_checks.sort!
    end

    def self.client
      UC3::UC3Client.clients.fetch(self.class.to_s, TestClient.new)
    end

    attr_reader :test_paths, :consistency_checks

    def enabled
      true
    end
  end
end
