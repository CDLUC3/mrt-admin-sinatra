# frozen_string_literal: true

require 'aws-sdk-codeartifact'
require_relative '../uc3_client'

# Scope custom code for UC3 to distinguish from 3rd party classes
module UC3Code
  # Query for repository artifacts by code
  class CodeArtifactClient < UC3::UC3Client
    ARTDOMAIN = 'cdlib-uc3-mrt'
    ARTREPOSITORY = 'uc3-mrt-java'
    ARTFORMAT = 'maven'
    ARTNAMESPACE = 'org.cdlib.mrt'

    def initialize
      @client = Aws::CodeArtifact::Client.new(region: UC3::UC3Client.region)
      @client.describe_domain(domain: ARTDOMAIN)
      super(enabled: enabled)
    rescue StandardError => e
      super(enabled: false, message: e.to_s)
    end

    def enabled
      !@client.nil?
    end

    def list_package_versions(repohash: {})
      res = {}
      return res unless enabled

      repohash.fetch(:artifacts, []).each do |artifact|
        begin
          pv = @client.list_package_versions(
            domain: ARTDOMAIN,
            repository: ARTREPOSITORY,
            package: artifact,
            format: ARTFORMAT,
            namespace: ARTNAMESPACE
          )
        rescue StandardError => e
          puts "Client ERR: #{e}: #{@client}"
          return res
        end
        pv.versions.each do |v|
          res[v.version] = res.fetch(v.version, [])
          res[v.version] << artifact
        end
      end
      res
    end
  end
end
