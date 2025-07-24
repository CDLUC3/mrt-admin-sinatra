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

    def cluster_name
      ENV.fetch('ECS_STACK_NAME', 'mrt-ecs-stack')
    end

    def initialize
      @client = Aws::ECS::Client.new(
        region: UC3::UC3Client.region
      )
      @ecr_client = UC3Code::ECRImagesClient.new
      @services = {}
      # An ECS Service has a ServiceDeployment which has a TargetServiceRevision.
      # A ServiceRevision has ContainerImage which has an ImageDigest.
      # The ImageDigest is the identity key for an image inside of an ECR Repository.
      @client.list_services(cluster: cluster_name, max_results: 20).service_arns.each do |arn|
        @client.describe_services(cluster: cluster_name, services: [arn]).services.each do |svc|
          digest = nil
          image = nil
          @client.list_service_deployments(
            cluster: cluster_name,
            service: arn,
            status: ['SUCCESSFUL']
          ).service_deployments.each do |sd|
            @client.describe_service_revisions(
              service_revision_arns: [sd.target_service_revision_arn]
            ).service_revisions.each do |sr|
              sr.container_images.each do |ci|
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

    def redeploy_service(service)
      return unless enabled

      @client.update_service(
        cluster: cluster_name,
        service: service,
        force_new_deployment: true
      ).to_json
    end

    def scale_up_service(service)
      return unless enabled

      @client.update_service(
        cluster: cluster_name,
        service: service,
        desired_count: 2
      ).to_json
    end

    def scale_down_service(service)
      return unless enabled

      @client.update_service(
        cluster: cluster_name,
        service: service,
        desired_count: 1
      ).to_json
    end
  end
end
