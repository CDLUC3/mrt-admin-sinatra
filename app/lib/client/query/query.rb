# frozen_string_literal: true

# require 'mysql2'
require 'yaml'
require_relative '../uc3_client'

# Scope custom code for UC3 to distinguish from 3rd party classes
module UC3Resources
  # Query for repository images by tag
  class QueryClient < UC3::UC3Client
    def initialize
      map = lookup_map('app/config/query.lookup.yml')
      config = resolve_lookup('app/config/query.template.yml', map)
      dbconf = config.fetch('dbconf', {})
      @client = nil
      # @client = Mysql2::Client.new(dbconf)
      super(enabled)
    rescue StandardError => e
      super(false, message: e.to_s)
    end

    def enabled
      !@client.nil?
    end
  end
end
