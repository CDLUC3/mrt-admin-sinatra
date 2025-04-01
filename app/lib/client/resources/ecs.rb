# frozen_string_literal: true

require 'aws-sdk-ecs'
require_relative '../uc3_client'

# Scope custom code for UC3 to distinguish from 3rd party classes
module UC3Resources
  # Query for repository images by tag
  class ServicesClient < UC3::UC3Client
    def initialize
      @client = Aws::ECS::Client.new(
        region: UC3::UC3Client.region
      )
      @services = {}
      # An ECS Service has a ServiceDeployment which has a TargetServiceRevision.
      # A ServiceRevision has ContainerImage which has an ImageDigest.
      # The ImageDigest is the identity key for an image inside of an ECR Repository.
      @client.list_services(cluster: 'mrt-ecs-stack').service_arns.each do |arn|
        @client.describe_services(cluster: 'mrt-ecs-stack', services: [arn]).services.each do |svc|
          digest = nil
          @client.list_service_deployments(
            cluster: 'mrt-ecs-stack', 
            service: arn, 
            status: ["SUCCESSFUL"]
          ).service_deployments.each do |sd|
            @client.describe_service_revisions(service_revision_arns: [sd.target_service_revision_arn]).service_revisions.each do |sr|
              sr.container_images.each do |ci|
                digest = ci.image_digest
              end
            end
            break
          end
          dep = svc.deployments ? svc.deployments[0] : {}
          @services[svc.service_name] = {
            name: svc.service_name,
            desired_count: svc.desired_count,
            running_count: svc.running_count,
            pending_count: svc.pending_count,
            created: dep.created_at,
            updated: dep.updated_at,
            image_digest: digest
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
          AdminUI::Column.new(:image_digest, header: 'Image Digest')
        ]
      )
      return table unless enabled

      @services.sort.each do |_key, value|
        table.add_row(AdminUI::Row.make_row(table.columns, value))
      end
      table
    end
  end
end
