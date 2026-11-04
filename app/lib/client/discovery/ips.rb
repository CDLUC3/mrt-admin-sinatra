# frozen_string_literal: true

require 'aws-sdk-servicediscovery'
require_relative '../uc3_client'

# Scope custom code for UC3 to distinguish from 3rd party classes
module UC3Discovery
  # Query for repository artifacts by code
  class ServiceIps < UC3::UC3Client

    def initialize
      @client = Aws::ServiceDiscovery::Client.new(region: UC3::UC3Client.region)
      @service_ips = {}
      @modified = nil
      super(enabled: enabled)
    rescue StandardError => e
      super(enabled: false, message: e.to_s)
    end

    def enabled
      !@client.nil?
    end

    def service_ips()
      @service_ips = {} if @modified && (Time.now - @modified) > 60
      return @service_ips unless @service_ips.empty?
      @modified = Time.now
      %w[ui audit replic inventory admintool].each do |service|
        @client.discover_instances(
          service_name: service,
          namespace_name: "merritt-#{UC3::UC3Client.stack_name}",
          health_status: 'HEALTHY'
        ).instances.each do |instance|
          @service_ips[service] |= []
          @service_ips[service] << instance.attributes['AWS_INSTANCE_IPV4']
        end
      end
      @service_ips
    end

  end
end
