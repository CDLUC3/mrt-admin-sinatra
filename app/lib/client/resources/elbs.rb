# frozen_string_literal: true

require 'aws-sdk-elasticloadbalancingv2'
require_relative '../uc3_client'

# Scope custom code for UC3 to distinguish from 3rd party classes
module UC3Resources
  # Query for repository images by tag
  class LoadBalancerClient < UC3::UC3Client
    def initialize
      @client = Aws::ElasticLoadBalancingV2::Client.new(
        region: UC3::UC3Client.region
      )
      @elbs = {}
      @arns = {}
      @client.describe_load_balancers.load_balancers.each do |lb|
        @elbs[lb.load_balancer_name] = {
          arn: lb.load_balancer_arn,
          name: lb.load_balancer_name,
          dns: lb.dns_name,
          type: lb.type,
          scheme: lb.scheme,
          tgname: [],
          listener: []
        }
        @arns[lb.load_balancer_arn] = lb.load_balancer_name
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
          AdminUI::Column.new(:scheme, header: 'Scheme', filterable: true),
          AdminUI::Column.new(:program, header: 'Program', filterable: true),
          AdminUI::Column.new(:service, header: 'Service', filterable: true),
          AdminUI::Column.new(:subservice, header: 'Subservice', filterable: true),
          AdminUI::Column.new(:tgname, header: 'TG Name'),
          AdminUI::Column.new(:listener, header: 'Listener')
        ]
      )
      @arns.each_key do |arn|
        @client.describe_tags(resource_arns: [arn]).tag_descriptions.each do |tagdesc|
          @elbs[@arns[arn]][:program] = tagdesc.tags.find { |t| t.key == 'Program' }&.value
          @elbs[@arns[arn]][:service] = tagdesc.tags.find { |t| t.key == 'Service' }&.value
          @elbs[@arns[arn]][:subservice] = tagdesc.tags.find { |t| t.key == 'Subservice' }&.value
        end
      end
      @client.describe_target_groups.target_groups.each do |tg|
        tg.load_balancer_arns.each do |arn|
          lb = @arns.fetch(arn, '')
          next if lb.empty?

          @elbs[lb][:tgname] << "#{tg.target_type}: #{tg.target_group_name}"
        end
      end
      @elbs.sort.each do |key, value|
        @client.describe_listeners(load_balancer_arn: value[:arn]).listeners.each do |listener|
          listener.default_actions.each do |action|
            value[:listener] << action.type
          end
        end
        table.add_row(AdminUI::Row.make_row(table.columns, value))
      end
      table
    end
  end
end
