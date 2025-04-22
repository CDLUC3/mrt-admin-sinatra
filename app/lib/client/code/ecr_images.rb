# frozen_string_literal: true

require 'aws-sdk-ecr'
require_relative '../uc3_client'

# Scope custom code for UC3 to distinguish from 3rd party classes
module UC3Code
  # Query for repository images by tag
  class ECRImagesClient < UC3::UC3Client
    def initialize
      @client = Aws::ECR::Client.new(region: UC3::UC3Client.region)
      @client.describe_registry
      super(enabled: enabled)
    rescue StandardError => e
      super(enabled: false, message: e.to_s)
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

    def list_images(repohash: {})
      res = []
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

          rec = {tag: tag, digest: img.image_digest, image: image, pushed: nil, pulled: nil}
          @client.describe_images(
            repository_name: image,
            image_ids: [
              {
                image_tag: tag,
                image_digest: img.image_digest
              }
            ]
          ).image_details.each do |imgdet|
            rec[:pushed] = date_format(imgdet.image_pushed_at)
            rec[:pulled] = date_format(imgdet.last_recorded_pull_time)
            rec[:actions] = [
              {
                value: 'Delete',
                href: "/source/images/delete/#{tag}",
                cssclass: 'button',
                post: true,
                disabled: false,
                data: image
              }
            ]
          end
          res << rec
        end
      end
      res
    end

    def image_table(res)
      table = AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:tag, header: 'Tag', filterable: true),
          AdminUI::Column.new(:image, header: 'Image', filterable: true),
          AdminUI::Column.new(:digest, header: 'Digest', filterable: true),
          AdminUI::Column.new(:pushed, header: 'Pushed At'),
          AdminUI::Column.new(:pulled, header: 'Last Pulled At'),
          AdminUI::Column.new(:actions, header: 'Actions')
        ]
      )
      res.each do |rec|
        table.add_row(
          AdminUI::Row.make_row(
            table.columns,
            rec
          )
        )
      end
      table
    end

    def delete_image(tag, image)
      @client.batch_delete_image(
        repository_name: image,
        image_ids: [
          {
            image_tag: tag
          }
        ]
      )
    end
  end
end
