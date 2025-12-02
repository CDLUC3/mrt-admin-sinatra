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

    def list_images(repohash: {})
      res = {}
      dig = {}
      return res unless enabled

      tagimages = repohash.fetch(:image_repos, [])
      tagimages.each do |image|
        begin
          imglist = @client.list_images(
            repository_name: image
          )
        rescue StandardError
          # puts "Client ERR: #{e}: #{@client}"
          return res
        end
        imglist.image_ids.each do |img|
          tag = img.image_tag
          next if tag.nil?
          next if tag =~ /^archive/

          rec = { tag: tag,
                  digest: img.image_digest,
                  image: image,
                  pushed: nil,
                  pulled: nil,
                  matching_tags: [],
                  actions: []
          }
          dig[img.image_digest] = dig.fetch(img.image_digest, [])
          dig[img.image_digest] << tag
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
          end
          res[tag] = res.fetch(tag, [])
          res[tag] << rec
        end
      end
      res.each do |tag, arr|
        arr.each do |rec|
          image = rec[:image]
          dig[rec[:digest]].each do |t|
            next if t == tag

            rec[:matching_tags] << t
          end

          rec[:deployed] = UC3::UC3Client.deployed_tag?(tag, rec[:matching_tags])

          if rec[:deployed]
            rec[:actions] << {
              value: 'STACK TAG',
              cssclass: 'button',
              disabled: true,
              href: '#',
              title: 'This image tag is a special tag that corresponds to a Merritt stack name.  ' \
                     'This should not be deleted.'
            }
            next
          end

          reposhort = File.basename(repohash.fetch(:repo, ''))
          deployed_tags = UC3S3::ConfigObjectsClient.client.get_release_manifest_deploy_tags(reposhort)
          if deployed_tags.include?(tag)
            rec[:actions] << {
              value: 'DEPLOYED',
              cssclass: 'button',
              disabled: true,
              href: '#',
              title: 'This image tag is deployed in a release manifest'
            }
            next
          end

          rec[:actions] << [
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
      res
    end

    def image_table(res)
      table = AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:tag, header: 'Image Tag'),
          AdminUI::Column.new(:image, header: 'Image'),
          AdminUI::Column.new(:digest, header: 'Digest'),
          AdminUI::Column.new(:pushed, header: 'Pushed At'),
          AdminUI::Column.new(:matching_tags, header: 'Matching Image Tags'),
          AdminUI::Column.new(:actions, header: 'Actions')
        ],
        description: "#### Tag deletion rules:\n\n" \
                     "- Tags matching Merritt stack names cannot be deleted\n" \
                     '- Tags registered in the [ECS Release Manifest](/merritt_manifest) cannot be deleted'
      )
      res.each_key do |tag|
        next if UC3::UC3Client.semantic_prefix_tag?(tag)

        res.fetch(tag, []).each do |rec|
          table.add_row(
            AdminUI::Row.make_row(
              table.columns,
              rec
            )
          )
        end
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

    def retag_image(tag, newtag, image)
      resp = @client.batch_get_image(
        repository_name: image,
        image_ids: [
          {
            image_tag: tag
          }
        ]
      )
      @client.put_image(
        repository_name: image,
        image_manifest: resp.images[0].image_manifest,
        image_tag: newtag
      )
    end

    def untag_image(tag, image)
      delete_image(tag, image)
    end

    def get_image_tags_by_digest(image, tag, digest)
      arr = []
      return arr unless enabled
      return arr unless image =~ /^mrt-(dashboard|ingest|store|inventory|audit|replic|admin-sinatra)$/

      begin
        resp = @client.describe_images(
          repository_name: image,
          image_ids: [
            {
              image_digest: digest
            }
          ],
          filter: {
            tag_status: 'TAGGED'
          }
        )
        resp.image_details.each do |img|
          next if img.image_tags.nil?

          img.image_tags.each do |t|
            next if t == tag
            next if t =~ /^archive/

            arr << t
          end
        end
      rescue StandardError
        # puts "Client ERR: #{e}"
      end
      arr
    end
  end
end
