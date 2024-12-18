# frozen_string_literal: true

require 'aws-sdk-ecr'
require_relative '../uc3_client'

# Scope custom code for UC3 to distinguish from 3rd party classes
module UC3Code
  # Query for repository images by tag
  class ECRImagesClient < UC3::UC3Client
    def initialize
      @client = Aws::ECR::Client.new(region: UC3::UC3Client::region)
      @client.describe_registry
      super(enabled)
    rescue StandardError => e
      super(false, message: e.to_s)
    end

    def enabled
      !@client.nil?
    end

    def list_image_tags(repohash: {})
      res = {}
      return res unless enabled

      repohash.fetch(:image_repos, []).each do |image|
        begin
          imglist = @client.list_images(
            repository_name: image
          )
        rescue StandardError => e
          puts "Client ERR: #{e}: #{@client}"
          return res
        end
        imglist.image_ids.each do |img|
          tag = img.image_tag
          next if tag.nil?

          res[tag] = res.fetch(tag, [])
          res[tag] << image
        end
      end
      res
    end
  end
end
