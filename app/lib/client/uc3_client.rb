# frozen_string_literal: true

require 'aws-sdk-ssm' unless ENV.fetch('MERRITT_ECS', '').empty?
require 'mustache'
require 'yaml'
require_relative '../ui/table'
require_relative '../util/manifest_to_yaml'

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

    ECS_DBSNAPSHOT = 'ecs-dbsnapshot'
    ECS_DEV = 'ecs-dev'
    ECS_EPHEMERAL = 'ecs-ephemeral'
    ECS_STG = 'ecs-stg'
    ECS_PRD = 'ecs-prd'

    @clients = {}

    def self.client
      UC3::UC3Client.clients.fetch(self.class.to_s, UC3Client.new)
    end

    def initialize(enabled: true, message: '')
      UC3Client.clients[self.class.to_s] = { name: self.class.to_s, enabled: enabled, message: message }
      @enabled = enabled
    end

    attr_reader :enabled

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
      return unless !qc.nil? && qc.enabled

      begin
        params = {}
        params['check_name'] = path
        params['status'] = status.to_s
        qc.query_update(
          '/ops/log-consistency',
          params,
          purpose: 'Record Consistency status'
        )
      rescue StandardError => e
        puts "Error recording status for #{path}: #{e.message}"
      end
    end

    def date_format(date, convert_timezone: false, format: '%Y-%m-%d %H:%M:%S')
      return '' if date.nil? || date.to_s.empty?

      d = DateTime.parse(date.to_s).to_time
      return '' if d.nil?

      d = d.localtime if convert_timezone
      d.strftime(format)
    end

    def self.region
      ENV['AWS_REGION'] || 'us-west-2'
    end

    def self.cluster_name
      ENV.fetch('ECS_STACK_NAME', 'mrt-ecs-dev-stack')
    end

    def self.stack_name
      ENV.fetch('MERRITT_ECS', 'ecs-dev')
    end

    def self.stack_name_brief
      ENV.fetch('MERRITT_ECS', 'ecs-dev').gsub('ecs-', '')
    end

    def self.dbsnapshot_stack?
      stack_name == ECS_DBSNAPSHOT
    end

    def self.prod_stack?
      stack_name == ECS_PRD
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

    def self.lookup_map_by_filename(filename, key: nil, symbolize_names: false)
      map = YAML.safe_load_file(filename, aliases: true)
      lookup_map(map, key: key, symbolize_names: symbolize_names)
    end

    def self.lookup_map(map, key: nil, symbolize_names: false)
      unless ENV.fetch('MERRITT_ECS', '').empty?
        ssm = Aws::SSM::Client.new(
          region: UC3::UC3Client.region
        )
      end
      map = map.fetch(key, {}) unless key.nil?
      map.clone.each do |key, value|
        if key == '_fixed'
          map[key].each do |k, v|
            map[k] = v
          end
        end
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
      map = JSON.parse(map.to_json, symbolize_names: true) if symbolize_names
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

    def self.make_url_with_key(path, params, key, value)
      p = params.clone
      uri = URI(path)
      p[key] = value
      uri.query = URI.encode_www_form(p)
      uri.to_s
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
                     name: { value: '..', href: "/ops/ingest-folders/list?path=#{File.dirname(path)}" },
                     created: '',
                     size: '',
                     actions: []
                   }
                 else
                   {
                     name: { value: folder, href: "/ops/ingest-folders/list?path=#{path}/#{folder}" },
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
                     href: '/ops/ingest-folders/delete',
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
      name = '-name "latest_snapshot.#{UC3::UC3Client.stack_name}.20*"'
      `find #{DIR}/zk-snapshots -maxdepth 1 #{name} -mtime +3 | xargs rm -rf`
    end
  end

  # Identify routes for Consistency Checks and for Unit Testing
  class TestClient < UC3Client
    CONSIS_QUERIES = %w[
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
    ].freeze

    def initialize
      super(enabled: true)

      @test_paths = []
      @consistency_checks = []

      UC3Query::QueryClient.client.queries.each do |name, query|
        next if query.fetch(:update, false) || query.fetch(:non_report, false) || query.fetch(:test_skip, false)

        name = name.to_s
        CONSIS_QUERIES.each do |pattern|
          next if name =~ %r{/objlist}

          @consistency_checks << name if name =~ /#{pattern}/
        end
        next if name =~ %r{/objlist}

        @test_paths << name unless @consistency_checks.include?(name)
        query.fetch(:unit_tests, []).each do |params|
          @test_paths << "#{name}#{params}"
        end
      end

      # These GET operations require specific url parameters that are not readily available for a unit test
      # Also, these tests are not activated for every stack.
      skiplist = %w[
        /ops/storage/manifest
        /ops/storage/manifest-yaml
        /ops/storage/ingest-checkm
        /ops/storage/benchmark-fixity
        /ops/storage/benchmark-fixity-nodes
        /ops/storage/benchmark-fixity-audit
        /ops/storage/benchmark-fixity-access
      ]

      # These GET operations require specific url parameters that are not readily available for a unit test
      # Also, these tests are not activated for every stack.
      if AdminUI::TopMenu.instance.skip_paths.include?('/ops/zk/ingest/jobs-by-collection')
        skiplist += %w[
          /ops/zk/ingest/jobs-by-collection/filtered
          /ops/zk/ingest/jobs-by-collection-and-batch/filtered
        ]
      end

      # These GET operations require specific url parameters that are not readily available for a unit test
      # Also, these tests are not activated for every stack.
      if AdminUI::TopMenu.instance.skip_paths.include?('/ops/zk/nodes')
        skiplist += %w[
          /ops/zk/nodes/node-names
        ]
      end

      Sinatra::Application.routes['GET'].each do |path, route|
        # .each_keys does not work, so make use of route object
        puts "Route #{path}: #{route.inspect}" unless route.empty?
        path = path.to_s

        next if path.include?('**')
        next if path.include?('*/*')

        if skiplist.include?(path)
          # skip from unit tests
        elsif AdminUI::TopMenu.instance.skip_paths.include?(path)
          # skip from unit tests
        elsif path.include?('*')
          if path.start_with?('/source/')
            UC3Code::SourceCodeClient.client.reponames.each do |repo|
              next if %w[ui admintool].include?(repo.to_s) && path.include?('artifacts')
              next if %w[core core-bom core-parprop cloud zk].include?(repo.to_s) && path.include?('images')
              next if %w[core-bom core-parprop].include?(repo.to_s) && path.include?('tags')

              rpath = path.gsub('*', repo.to_s)
              @test_paths << rpath unless AdminUI::TopMenu.instance.skip_paths.include?(rpath)
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
            /ops/ingest-folders/list
          ].each do |pattern|
            @consistency_checks << path if path =~ /#{pattern}/
          end
        end
      end
      @test_paths = @test_paths.uniq.sort
      @consistency_checks = @consistency_checks.uniq.sort
    end

    def self.client
      UC3::UC3Client.clients.fetch(self.class.to_s, TestClient.new)
    end

    attr_reader :test_paths, :consistency_checks
  end

  # Call endpoints in Merritt Services
  class MerrittEndpointClient < UC3Client
    def initialize
      super(enabled: true)
    end

    def self.client
      UC3::UC3Client.clients.fetch(self.class.to_s, MerrittEndpointClient.new)
    end
  end
end
