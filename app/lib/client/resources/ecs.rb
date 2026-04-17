# frozen_string_literal: true

require 'aws-sdk-ecs'
require 'aws-sdk-cloudwatchevents'
require_relative '../uc3_client'
require_relative '../code/ecr_images'

# Scope custom code for UC3 to distinguish from 3rd party classes
module UC3Resources
  # Query for repository images by tag
  class ServicesClient < UC3::UC3Client
    MERRITT_SERVICES = %w[ingest inventory audit replic access store ui admintool].freeze

    def self.client
      UC3::UC3Client.clients.fetch(self.class.to_s, ServicesClient.new)
    end

    def initialize
      @client = Aws::ECS::Client.new(
        region: UC3::UC3Client.region
      )
      @cwclient = Aws::CloudWatchEvents::Client.new(
        region: UC3::UC3Client.region
      )
      @ecr_client = UC3Code::ECRImagesClient.new
      super(enabled: enabled)
    rescue StandardError => e
      super(enabled: false, message: e.to_s)
    end

    def enabled
      !@client.nil?
    end

    def list_services_data
      services = {}
      return services unless enabled

      begin
        # An ECS Service has a ServiceDeployment which has a TargetServiceRevision.
        # A ServiceRevision has ContainerImage which has an ImageDigest.
        # The ImageDigest is the identity key for an image inside of an ECR Repository.
        @client.list_services(cluster: UC3::UC3Client.cluster_name, max_results: 20).service_arns.each do |arn|
          puts "ARN #{arn}"
          @client.describe_services(cluster: UC3::UC3Client.cluster_name, services: [arn]).services.each do |svc|
            digest = nil
            image = nil
            pendcount = @client.list_service_deployments(
              cluster: UC3::UC3Client.cluster_name,
              service: arn,
              status: %w[PENDING IN_PROGRESS]
            ).service_deployments.length
            @client.list_service_deployments(
              cluster: UC3::UC3Client.cluster_name,
              service: arn,
              status: ['SUCCESSFUL']
            ).service_deployments.each do |sd|
              @client.describe_service_revisions(
                service_revision_arns: [sd.target_service_revision_arn]
              ).service_revisions.each do |sr|
                sr.container_images.each do |ci|
                  # next if ci.image.to_s =~ /fluent-bit/ # skip sidecar images

                  puts "Container Image #{ci.image} with digest #{ci.image_digest}"
                  digest = ci.image_digest
                  image = ci.image.to_s.gsub(%r{^.*amazonaws.com/}, '')
                end
              end
              break unless image.nil?
            end

            dep = svc.deployments ? svc.deployments[0] : {}
            next if image.nil?

            image_name = image.split(':')[0]
            image_tag = image.split(':')[1]

            matching = @ecr_client.get_image_tags_by_digest(image_name, image_tag, digest)

            name = svc.service_name

            status = 'SKIP'

            if svc.running_count.positive?
              status = if dep.updated_at > (Date.today - 7).to_time
                         'PASS'
                       elsif dep.updated_at > (Date.today - 14).to_time
                         'WARN'
                       else
                         'FAIL'
                       end
              status = 'FAIL' if matching.empty? && MERRITT_SERVICES.include?(name)
            end

            services[name] = {
              name: name,
              deploying: pendcount.positive?,
              desired_count: svc.desired_count,
              running_count: svc.running_count,
              pending_count: svc.pending_count,
              created: date_format(dep.created_at, convert_timezone: true),
              updated: date_format(dep.updated_at, convert_timezone: true),
              image: [image, digest],
              tags: matching,
              manifest_tag: @ecr_client.get_manifest_tag(image_name),
              status: status
            }
          end
        end
      rescue StandardError => e
        puts "Error listing services: #{e.message}"
      end
      services
    end

    def service_description
      <<~DESC
        #### Service Status Criteria

        - SKIP if service is not running
        - FAIL if no matching tags for a Merritt Service
        - PASS if service is running and updated within the last 7 days
        - WARN if updated within the last 14 days
        - FAIL if not updated in over 14 days

        #### Matching Tags

        - The matching tags contain the list of ECR tags that match the digest of the running image.
        - The stack deployment tag (i.e. ecs-prd) is excluded from this list
        - For branches and tags that are listed in the [ECS Manifest](/merritt_manifest),
          the images will be rebuilt daily
        - A named archive tag should confinue to be present
        - If a matching tag is not present, there is a risk that the ECR lifecycle policy may purge the image,
          which would prevent redeployments.
        - See [Merritt Tagging Conventions](https://github.com/CDLUC3/mrt-admin-sinatra/blob/main/present/tagging/build.md) for more details
      DESC
    end

    def list_services
      table = AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:name, header: 'Name'),
          AdminUI::Column.new(:deploying, header: 'Deploying'),
          AdminUI::Column.new(:desired_count, header: 'Desired'),
          AdminUI::Column.new(:running_count, header: 'Running'),
          AdminUI::Column.new(:pending_count, header: 'Pending'),
          AdminUI::Column.new(:updated, header: 'Updated'),
          AdminUI::Column.new(:image, header: 'Image'),
          AdminUI::Column.new(:tags, header: 'Matching Tags'),
          AdminUI::Column.new(:manifest_tag, header: 'Manifest Tag'),
          AdminUI::Column.new(:status, header: 'Status')
        ],
        description: service_description
      )

      return table unless enabled

      list_services_data.sort.each do |_key, value|
        table.add_row(AdminUI::Row.make_row(table.columns, value))
      end
      table
    end

    def list_tasks_data
      tasks = {}
      return tasks unless enabled

      begin
        @client.list_tasks(cluster: UC3::UC3Client.cluster_name).task_arns.each do |task_arn|
          id = task_arn.split('/').last
          next if id.nil?

          @client.describe_tasks(
            cluster: UC3::UC3Client.cluster_name,
            tasks: [id]
          ).tasks.each do |task|
            next if task.group =~ /service:/ # skip service tasks

            tasks[id] = {
              id: id,
              name: task.group,
              started: date_format(task.started_at, convert_timezone: true),
              stopped: date_format(task.stopped_at, convert_timezone: true),
              last_status: task.last_status
            }
          end
        end
      rescue StandardError => e
        puts "Error listing tasks: #{e.message}"
      end
      tasks
    end

    def list_tasks
      table = AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:name, header: 'Name'),
          AdminUI::Column.new(:id, header: 'Id'),
          AdminUI::Column.new(:last_status, header: 'Status'),
          AdminUI::Column.new(:started, header: 'Started'),
          AdminUI::Column.new(:stopped, header: 'Stopped')
        ]
      )
      return table unless enabled

      list_tasks_data.sort.each do |_key, value|
        table.add_row(AdminUI::Row.make_row(table.columns, value))
      end
      table
    end

    def list_task_definitions_data
      taskdefs = {}
      return taskdefs unless enabled

      begin
        prefix = "mrt-task-#{ENV.fetch('MERRITT_ECS', '')}"
        @client.list_task_definition_families(family_prefix: prefix).families.each do |family|
          @client.list_task_definitions(family_prefix: family).task_definition_arns.each do |tdarn|
            tdesc = @client.describe_task_definition(task_definition: tdarn).task_definition
            next if tdesc.nil?

            next unless tdesc.container_definitions

            tdesc.container_definitions.each do |td|
              next if td.name =~ /chrome/ # skip sidecar images

              taskdefs[family] = {
                family: family,
                name: td.name,
                image: td.image,
                entrypoint: td.entry_point ? td.entry_point[0] : ''
              }
            end
          end
        end
      rescue StandardError => e
        puts "Error listing tasks: #{e.message}"
      end
      taskdefs
    end

    def list_task_definitions
      table = AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:family, header: 'Family'),
          AdminUI::Column.new(:name, header: 'Name'),
          AdminUI::Column.new(:image, header: 'Image'),
          AdminUI::Column.new(:entrypoint, header: 'Entrypoint')
        ]
      )
      return table unless enabled

      list_task_definitions_data.sort.each do |_key, value|
        table.add_row(AdminUI::Row.make_row(table.columns, value))
      end
      table
    end

    def list_scheduled_tasks_data
      tasks = {}
      return tasks unless enabled

      begin
        @cwclient.list_rules.rules.each do |rule|
          task = {
            rule: rule.name,
            keep: false
          }
          @cwclient.list_targets_by_rule(rule: rule.name).targets.each do |target|
            next unless target.ecs_parameters

            task[:arn] = target.ecs_parameters.task_definition_arn
            task[:tarn] = target.arn
            task[:keep] = true if target.arn =~ %r{/#{UC3::UC3Client.cluster_name}$}
          end

          next unless task[:keep]

          tdesc = @client.describe_task_definition(task_definition: task[:arn]).task_definition

          next unless tdesc.container_definitions

          tdesc.container_definitions.each do |td|
            next if td.name =~ /chrome/ # skip sidecar images

            task[:family] = tdesc.family
            task[:name] = td.name
            task[:image] = td.image
            task[:entrypoint] = td.entry_point ? td.entry_point[0] : ''
          end

          @cwclient.describe_rule(name: rule.name).tap do |rdesc|
            task[:schedule] = rdesc.schedule_expression
            sched = rdesc.schedule_expression.gsub('cron(', '').gsub(')', '')
            hour = sched.split[1]
            min = sched.split[0]
            if hour =~ /^\d+$/ && min =~ /^\d+$/
              time = Time.utc(Time.now.year, Time.now.month, Time.now.day, hour.to_i, min.to_i, 0)
              task[:time] = date_format(time, convert_timezone: true, format: '%H:%M')
            end
          end

          tasks[rule.name] = task
        end
      rescue StandardError => e
        puts "Error listing task schedules: #{e.message}"
      end
      tasks
    end

    def list_scheduled_tasks
      table = AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:rule, header: 'Rule'),
          AdminUI::Column.new(:schedule, header: 'Schedule (UTC)'),
          AdminUI::Column.new(:time, header: 'Time (Local)'),
          AdminUI::Column.new(:name, header: 'Name'),
          AdminUI::Column.new(:image, header: 'Image'),
          AdminUI::Column.new(:entrypoint, header: 'Entrypoint')
        ]
      )
      return table unless enabled

      list_scheduled_tasks_data.sort.each do |_key, value|
        table.add_row(AdminUI::Row.make_row(table.columns, value))
      end
      table
    end

    def retag_and_redeploy_service(service)
      return unless enabled

      repo = case service
             when 'ui'
               'mrt-dashboard'
             when 'admintool'
               'mrt-admin-sinatra'
             else
               "mrt-#{service}"
             end

      tag = UC3S3::ConfigObjectsClient.client.get_ecs_release_manifest_stack_tag(repo)

      UC3Code::SourceCodeClient.client.retag_image(tag, UC3::UC3Client.stack_name, repo) unless tag.empty?

      @client.update_service(
        cluster: UC3::UC3Client.cluster_name,
        service: service,
        force_new_deployment: true
      ).to_json
    end

    def redeploy_service(service)
      return unless enabled

      @client.update_service(
        cluster: UC3::UC3Client.cluster_name,
        service: service,
        force_new_deployment: true
      ).to_json
    end

    def deploy_service(service)
      return unless enabled

      @client.update_service(
        cluster: UC3::UC3Client.cluster_name,
        service: service,
        desired_count: 1,
        force_new_deployment: true
      ).to_json
    end

    def stop_service(service)
      return unless enabled

      @client.update_service(
        cluster: UC3::UC3Client.cluster_name,
        service: service,
        desired_count: 0
      ).to_json
    end

    def network_configuration(service_arn)
      service = @client.describe_services(cluster: UC3::UC3Client.cluster_name, services: [service_arn]).services
      return {} if service.nil? || service.empty?

      deployment = service[0].deployments
      return {} if deployment.nil? || deployment.empty?

      deployment[0].network_configuration
    end

    def run_service_task(_service, label)
      return unless enabled

      prefix = "mrt-task-#{ENV.fetch('MERRITT_ECS', '')}-#{label}"

      tdarr = @client.list_task_definitions(family_prefix: prefix).task_definition_arns
      return "No Task Definition found for prefix #{prefix}" if tdarr.nil? || tdarr.empty?

      td = tdarr[0]
      # service_arn = "#{td.split(':')[0..4].join(':')}:service/#{UC3::UC3Client.cluster_name}/#{service}"
      # standalone tasks do not have a network config
      service_arn = "#{td.split(':')[0..4].join(':')}:service/#{UC3::UC3Client.cluster_name}/merritt-ops"

      @client.run_task(
        cluster: UC3::UC3Client.cluster_name,
        task_definition: td,
        launch_type: 'FARGATE',
        network_configuration: network_configuration(service_arn)
      ).to_json
    end

    def scale_up_service(service)
      return unless enabled

      @client.update_service(
        cluster: UC3::UC3Client.cluster_name,
        service: service,
        desired_count: 2
      ).to_json
    end

    def scale_down_service(service)
      return unless enabled

      @client.update_service(
        cluster: UC3::UC3Client.cluster_name,
        service: service,
        desired_count: 1
      ).to_json
    end
  end
end
