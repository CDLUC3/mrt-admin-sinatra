# frozen_string_literal: true

require 'aws-sdk-elasticloadbalancingv2'
require_relative '../uc3_client'

# Scope custom code for UC3 to distinguish from 3rd party classes
module UC3Resources
  # Query for repository images by tag
  class LoadBalancerClient < UC3::UC3Client
    def initialize
      @client = Aws::ElasticLoadBalancingV2::Client.new(
        region: UC3::UC3Client::region
      )
      @elbs = {}
      @client.describe_load_balancers.load_balancers.each do |lb|
        @elbs[lb.load_balancer_name] = {
          name: lb.load_balancer_name,
          dns: lb.dns_name,
          type: lb.type,
          scheme: lb.scheme
        }
      end
      super(enabled: enabled)
    rescue StandardError => e
      super(enabled: false, message: e.to_s)
    end

    def enabled
      !@client.nil?
    end

    def list_instances(filters: {})
      table = AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:name, header: 'Name'),
          AdminUI::Column.new(:dns, header: 'DNS'),
          AdminUI::Column.new(:type, header: 'Type', filterable: true),
          AdminUI::Column.new(:scheme, header: 'Scheme', filterable: true)
        ]
      )
      @elbs.sort.each do |key, value|
        table.add_row(AdminUI::Row.make_row(table.columns, value))
      end
    table
    end
  end
end
