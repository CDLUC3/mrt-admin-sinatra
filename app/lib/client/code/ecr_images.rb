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

          res[tag] = res.fetch(tag, {tag: tag, images: [], pushed: nil, pulled: nil})
          res[tag][:images] << image
          @client.describe_images(
            repository_name: image,
            image_ids: [
              {
                image_tag: tag,
                image_digest: img.image_digest
              }
            ]
          ).image_details.each do |imgdet|
            res[tag][:pushed] = date_format(imgdet.image_pushed_at)
            res[tag][:pulled] = date_format(imgdet.last_recorded_pull_time)
            res[tag][:actions] = [
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
        end
      end
      res
    end

    def image_table(res)
      table = AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:tag, header: 'Tag'),
          AdminUI::Column.new(:images, header: 'Images'),
          AdminUI::Column.new(:pushed, header: 'Pushed At'),
          AdminUI::Column.new(:pulled, header: 'Last Pulled At'),
          AdminUI::Column.new(:actions, header: 'Actions')
        ]
      )
      res.keys.each do |tag|
        table.add_row(
          AdminUI::Row.make_row(
            table.columns,
            res[tag]
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
