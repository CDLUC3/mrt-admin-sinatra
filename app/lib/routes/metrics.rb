# frozen_string_literal: true

require 'sinatra/base'
require_relative '../client/cloudwatch/metrics'

# custom sinatra routes
module Sinatra
  # client specific routes
  module UC3MetricsRoutes
    def self.registered(app)
      app.get '/ops/metrics/benchmark-retrieval/*' do |fname|
        adminui_show_table(
          AdminUI::Context.new(request.path, request.params),
          UC3CloudWatch::MetricsClient.client.metric_table(
            UC3CloudWatch::MetricsClient.client.retrieval_duration_sec_metrics(fname)
          )
        )
      end
    end
  end
  register UC3MetricsRoutes
end
