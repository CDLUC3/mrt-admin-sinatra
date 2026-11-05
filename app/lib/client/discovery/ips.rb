# frozen_string_literal: true

require 'aws-sdk-servicediscovery'
require_relative '../uc3_client'

# Scope custom code for UC3 to distinguish from 3rd party classes
module UC3Discovery
  # Query for repository artifacts by code
  class ServiceIpsClient < UC3::UC3Client
    def self.client
      UC3::UC3Client.clients.fetch(self.class.to_s, ServiceIpsClient.new)
    end

    def initialize
      @client = Aws::ServiceDiscovery::Client.new(region: UC3::UC3Client.region)
      @service_ips = {}
      @task_ips = {}
      @modified = nil
      super(enabled: enabled)
    rescue StandardError => e
      super(enabled: false, message: e.to_s)
    end

    def enabled
      !@client.nil?
    end

    def service_ips
      @service_ips = {} if @modified && (Time.now - @modified) > 60
      return @service_ips unless @service_ips.empty?

      @modified = Time.now
      %w[ui audit replic inventory admintool merritt-ops merritt-opswrite].each do |service|
        @client.discover_instances(
          service_name: service,
          namespace_name: "merritt-#{UC3::UC3Client.stack_name}",
          health_status: 'HEALTHY'
        ).instances.each do |instance|
          ipaddr = instance.attributes.fetch('AWS_INSTANCE_IPV4', '')
          next if ipaddr.empty?

          @service_ips[ipaddr] = service
        end
      end
      @service_ips
    end

    def task_ips
      @task_ips = {} if @modified && (Time.now - @modified) > 60
      return @task_ips unless @task_ips.empty?

      UC3Resources::ServicesClient.client.list_tasks_data.values.each do |task|
        ipaddr = task.fetch(:ipaddr, '')
        next if ipaddr.empty?
          
        @task_ips[ipaddr] = task.fetch(:name, '').gsub(/family:/, '').gsub("mrt-task-#{UC3::UC3Client.stack_name}-", '')
      end
      @task_ips
    end
  end
end
