# frozen_string_literal: true

require 'aws-sdk-ecs'
require_relative '../uc3_client'
require_relative '../code/ecr_images'

# Scope custom code for UC3 to distinguish from 3rd party classes
module UC3Resources
  # Query for repository images by tag
  class ServicesClient < UC3::UC3Client
    def self.client
      UC3::UC3Client.clients.fetch(self.class.to_s, ServicesClient.new)
    end

    def initialize
      @client = Aws::ECS::Client.new(
        region: UC3::UC3Client.region
      )
      @ecr_client = UC3Code::ECRImagesClient.new
      @services = {}
      @tasks = {}
      # An ECS Service has a ServiceDeployment which has a TargetServiceRevision.
      # A ServiceRevision has ContainerImage which has an ImageDigest.
      # The ImageDigest is the identity key for an image inside of an ECR Repository.
      @client.list_services(cluster: UC3::UC3Client.cluster_name, max_results: 20).service_arns.each do |arn|
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
                next if ci.image.to_s =~ /fluent-bit/ # skip sidecar images

                digest = ci.image_digest
                image = ci.image.to_s.gsub(%r{^.*amazonaws.com/}, '')
              end
            end
            break unless image.nil?
          end

          dep = svc.deployments ? svc.deployments[0] : {}
          image_name = image.split(':')[0]
          image_tag = image.split(':')[1]
          @services[svc.service_name] = {
            name: svc.service_name,
            deploying: pendcount.positive?,
            desired_count: svc.desired_count,
            running_count: svc.running_count,
            pending_count: svc.pending_count,
            created: date_format(dep.created_at, convert_timezone: true),
            updated: date_format(dep.updated_at, convert_timezone: true),
            image: [image, digest],
            tags: @ecr_client.get_image_tags_by_digest(image_name, image_tag, digest)
          }
        end
      end
      arns = []
      begin
        @client.list_tasks(cluster: UC3::UC3Client.cluster_name).task_arns.each do |task_arn|
          id = task_arn.split('/').last
          @client.describe_tasks(
            cluster: UC3::UC3Client.cluster_name,
            tasks: [id]
          ).tasks.each do |task|
            next if task.group =~ /service:/ # skip service tasks
            @tasks[id] = {
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
      super(enabled: enabled)
    rescue StandardError => e
      super(enabled: false, message: e.to_s)
    end

    def enabled
      !@client.nil?
    end

    def list_services
      table = AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:name, header: 'Name'),
          AdminUI::Column.new(:deploying, header: 'Deploying'),
          AdminUI::Column.new(:desired_count, header: 'Desired'),
          AdminUI::Column.new(:running_count, header: 'Running'),
          AdminUI::Column.new(:pending_count, header: 'Pending'),
          AdminUI::Column.new(:created, header: 'Created'),
          AdminUI::Column.new(:updated, header: 'Updated'),
          AdminUI::Column.new(:image, header: 'Image'),
          AdminUI::Column.new(:tags, header: 'Matching Tags')
        ]
      )
      return table unless enabled

      @services.sort.each do |_key, value|
        table.add_row(AdminUI::Row.make_row(table.columns, value))
      end
      table
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

      @tasks.sort.each do |_key, value|
        table.add_row(AdminUI::Row.make_row(table.columns, value))
      end
      table
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
