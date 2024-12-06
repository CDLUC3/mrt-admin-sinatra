require 'octokit'
require 'aws-sdk-ssm'
require_relative 'table'

# export GHTOKEN=pull from SSM /uc3/mrt/dev/github/readonly

Octokit.configure do |c|
  c.auto_paginate = true
end

class Github
  def initialize(repohash)
    @repo = repohash.fetch(:repo, '')
    @ssm = Aws::SSM::Client.new(region: ENV.fetch('AWS_REGION', 'us-west-2'))
    @token = @ssm.get_parameter(name: '/uc3/mrt/dev/github/readonly', with_decryption: true)[:parameter][:value]
    @client = Octokit::Client.new({access_token: @token})
    @tags = {}
    @commits = {}
    @releases = {}

    @table = FilterTable.new(
      # Tag	Date	Commit Sha	Documented Release	Artifacts	ECR Images	Actions
      columns: [
        Column.new(:tag, header: 'Tag', cssclass: 'tag'),
        Column.new(:date, header: 'Date', cssclass: 'date'),
        Column.new(:sha, header: 'Commit Sha', cssclass: 'sha'),
        Column.new(:release_name, header: 'Documented Release', cssclass: 'release'),
        Column.new(:artifacts, header: 'Artifacts', cssclass: 'artifacts'),
        Column.new(:images, header: 'ECR Images', cssclass: 'images'),
        Column.new(:actions, header: 'Actions', cssclass: 'actions', spanclass: '')
      ]
    )

    since = Time.now - 2 * 365 * 24 * 60 * 60
    @client.commits_since(@repo, since).each do |commit|
      @commits[commit.sha] = {
        sha: commit.sha,
        message: commit.commit.message,
        author: commit.commit.author.name,
        date: commit.commit.author.date,
        url: commit.html_url
      }
    end

    @client.releases(@repo).each do |rel|
      @releases[rel.tag_name] = {
        tag: rel.tag_name,
        name: rel.name,
        url: rel.html_url,
        draft: rel.draft
      }      
    end

    @client.tags(@repo).each do |tag|

      next if tag.name =~ /^sprint-/

      commit = @commits.fetch(tag.commit.sha, {})
      semantic = !(tag.name =~ /^\d+\.\d+\.\d+$/).nil?
      release = @releases.fetch(tag.name, {})

      next if commit.empty?

      has_release = !release.empty?
      @tags[tag.name] = {
        cssclass: "data #{semantic ? 'semantic' : 'other'}",
        tag: tag.name,
        date: commit.fetch(:date, ''),
        sha: [
          {
            value: tag.commit.sha,
            href: commit.fetch(:url, '')
          },
          commit.fetch(:message, ''),
          commit.fetch(:author, '')
        ],
        release:{
          value: has_release ? release.fetch(:name, '') : 'Create',
          href: has_release ? release.fetch(:url, '') : "https://github.com/#{repo}/releases/new?tag=#{tag.name}",
          cssclass: has_release ? (release.fetch(:draft, false) ? 'draft' : '') : 'button'
        },
        artifacts: 'tbd',
        images: 'tbd',
        actions: [
          {
            value: 'Deploy Dev',
            href: "#foo",
            cssclass: 'button-disabled',
            disabled: true
          },
          {
            value: 'Delete Artifacts',
            href: "#foo",
            cssclass: 'button-disabled',
            disabled: true
          }
        ]
      }
    end

    @tags.each do |tag, data|
      @table.add_row(
        Row.new(
          [
            data[:tag],
            data[:date],
            data[:sha],
            data[:release],
            data[:artifacts],
            data[:images],
            data[:actions]
          ],
          cssclass: data[:cssclass]
        )
      )
    end
  end

  def tags
    begin
      @tags.sort_by { |k, v| v[:date] }.reverse.to_h
    rescue
      @tags.sort_by { |k, v| k }.reverse.to_h
    end
  end

  attr_accessor :repo, :commits, :table
end