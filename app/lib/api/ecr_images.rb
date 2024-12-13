require 'aws-sdk-ecr'

class ECRImages
  def initialize(repohash)
    @client = Aws::ECR::Client.new(region: 'us-west-2')
    @images = repohash.fetch(:image_repos, [])
  end

  def list_image_tags
    res = {}
    @images.each do |image|
      imglist = @client.list_images(
        repository_name: image
      )
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
