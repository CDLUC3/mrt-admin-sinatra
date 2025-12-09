# frozen_string_literal: true

require 'sinatra/base'
require_relative '../client/cloudwatch/metrics'

# custom sinatra routes
module Sinatra
  # client specific routes
  module UC3MetricsRoutes
    def self.registered(app)
      app.get '/ops/metrics/benchmark-retrieval/*' do |fname|
        period_min = params.fetch('period_min', '15').to_i
        offset_days = params.fetch('offset_days', '7').to_i

        adminui_show_table(
          AdminUI::Context.new(request.path, request.params),
          UC3CloudWatch::MetricsClient.client.metric_table(
            UC3CloudWatch::MetricsClient.client.retrieval_duration_sec_metrics(fname, period_min: period_min,
              offset_days: offset_days)
          )
        )
      end
    end
  end
  register UC3MetricsRoutes
end
