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
    @client = Octokit::Client.new({access_token: @token})
    @tags = {}
    @commits = {}
    @releases = {}
    @repo = repo
    since = Time.now - 2 * 365 * 24 * 60 * 60
    @client.commits_since("cdluc3/#{repo}", since).each do |commit|
      @commits[commit.sha] = {
        sha: commit.sha,
        message: commit.commit.message,
        author: commit.commit.author.name,
        date: commit.commit.author.date,
        url: commit.html_url
      }
    end

    @client.releases("cdluc3/#{repo}").each do |rel|
      @releases[rel.tag_name] = {
        tag: rel.tag_name,
        name: rel.name,
        url: rel.html_url,
        draft: rel.draft
      }      
    end

    @client.tags("cdluc3/#{repo}").each do |tag|

      next if tag.name =~ /^sprint-/

      commit = @commits.fetch(tag.commit.sha, {})
      semantic = !(tag.name =~ /^\d+\.\d+\.\d+$/).nil?
      release = @releases.fetch(tag.name, {})

      next if commit.empty?

      @tags[tag.name] = {
        name: tag.name,
        semantic: semantic,
        sha: tag.commit.sha,
        url: commit.fetch(:url, ''),
        message: commit.fetch(:message, ''),
        date: commit.fetch(:date, ''),
        author: commit.fetch(:author, ''),
        has_release: !release.empty?,
        release_name: release.fetch(:name, '+'),
        release_url: release.fetch(:url, "https://github.com/CDLUC3/#{repo}/releases/new?tag=#{tag.name}"),
        release_draft: release.fetch(:draft, false)
      }
    end
  end

  def tags
    begin
      @tags.sort_by { |k, v| v[:date] }.reverse.to_h
    rescue
      @tags.sort_by { |k, v| k }.reverse.to_h
    end
  end

  attr_accessor :repo, :commits
end