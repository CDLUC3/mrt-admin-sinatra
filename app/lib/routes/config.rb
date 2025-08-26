# frozen_string_literal: true

require 'sinatra/base'
require_relative '../client/s3/config_objects'

# custom sinatra routes
module Sinatra
  # client specific routes
  module UC3S3Routes
    def self.registered(app)
      app.get '/ops/collections/profiles' do
        adminui_show_table(
          AdminUI::Context.new(request.path),
          UC3S3::ConfigObjectsClient.new.list_profiles
        )
      end

      app.get '/ops/collections/profiles/*' do |profile|
        content_type :text
        UC3S3::ConfigObjectsClient.new.get_profile(profile)
      end
    end
  end
  register UC3S3Routes
end
