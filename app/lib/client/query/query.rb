# frozen_string_literal: true

# require 'mysql2'
require_relative '../uc3_client'

# Scope custom code for UC3 to distinguish from 3rd party classes
module UC3Resources
  # Query for repository images by tag
  class QueryClient < UC3::UC3Client
    def initialize
      dbconf = {
        host: 'localhost',
        username: 'travis',
        database: 'mrt_dashboard_test',
        password: 'password',
        port: 3306,
        encoding: 'utf8mb4',
        collation: 'utf8mb4_unicode_ci'
      }
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
