require 'octokit'
require 'aws-sdk-ssm'

# export GHTOKEN=pull from SSM /uc3/mrt/dev/github/readonly

Octokit.configure do |c|
  c.auto_paginate = true
end

class Github
  def initialize(repo)
    @ssm = Aws::SSM::Client.new(region: ENV.fetch('AWS_REGION', 'us-west-2'))
    @token = @ssm.get_parameter(name: '/uc3/mrt/dev/github/readonly', with_decryption: true)[:parameter][:value]
    puts @token
    @client = Octokit::Client.new({access_token: @token})
    @tags = {}
    @repo = repo
    @client.tags(owner: 'cdluc3', name: repo).each do |tag|

      next if tag.name =~ /^sprint-/
      @tags[tag.name] = {
        name: tag.name, 
        semantic: !(tag.name =~ /^\d+\.\d+\.\d+$/).nil?,
        data: tag.methods.to_s
      }
    end
  end

  attr_accessor :repo, :tags
end