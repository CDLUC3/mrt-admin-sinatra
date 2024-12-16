# frozen_string_literal: true

require 'aws-sdk-codeartifact'
require_relative 'uc3_client'

module UC3
  class CodeArtifactClient < UC3Client
    def initialize
      @client = Aws::CodeArtifact::Client.new(region: 'us-west-2')
    rescue StandardError => e
      puts e
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
            domain: 'cdlib-uc3-mrt',
            repository: 'uc3-mrt-java',
            package: artifact,
            format: 'maven',
            namespace: 'org.cdlib.mrt'
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
