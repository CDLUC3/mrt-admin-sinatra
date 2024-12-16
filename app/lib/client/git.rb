# frozen_string_literal: true

require 'octokit'
require 'aws-sdk-ssm'
require_relative '../ui/table'
require_relative 'uc3_client'

# export GHTOKEN=pull from SSM /uc3/mrt/dev/github/readonly

module UC3
  Octokit.configure do |c|
    c.auto_paginate = true
  end

  class GithubClient < UC3Client
    NOACT = 'javascript:alert("Not yet implemented");'
    def initialize
      token = '' # TBD
      opts = {}
      opts[:access_token] = token unless token.empty?
      begin
        @client = Octokit::Client.new(opts)
      rescue StandardError => e
        puts e
      end
      @tags = {}
      @commits = {}
      @releases = {}
      @since = Time.now - (2 * 365 * 24 * 60 * 60)
    end

    def enabled
      !@client.nil?
    end

    attr_accessor :repo, :commits, :table

    def list_tags(repohash: {}, artifacts: {}, ecrimages: {})
      repo = repohash.fetch(:repo, '')

      table = FilterTable.new(
        # Tag	Date	Commit Sha	Documented Release	Artifacts	ECR Images	Actions
        columns: [
          Column.new(:tag, header: 'Tag', cssclass: 'tag'),
          Column.new(:date, header: 'Date', cssclass: 'date'),
          Column.new(:sha, header: 'Commit Sha', cssclass: 'sha'),
          Column.new(:release_name, header: 'Documented Release', cssclass: 'release'),
          Column.new(:artifacts, header: 'Artifacts', cssclass: 'artifacts'),
          Column.new(:images, header: 'ECR Images', cssclass: 'images'),
          Column.new(:actions, header: 'Actions', cssclass: 'actions', spanclass: '')
        ],
        filters: [
          Filter.new('Semantic Tags Only', 'other'),
          Filter.new('Has Release', 'no-release'),
          Filter.new('Has Artifact', 'no-artifact'),
          Filter.new('Has Image', 'no-image')
        ]
      )

      @client.commits_since(repo, @since).each do |commit|
        @commits[commit.sha] = {
          sha: commit.sha,
          message: commit.commit.message,
          author: commit.commit.author.name,
          date: commit.commit.author.date,
          url: commit.html_url
        }
      end

      @client.releases(repo).each do |rel|
        @releases[rel.tag_name] = {
          tag: rel.tag_name,
          name: rel.name,
          url: rel.html_url,
          draft: rel.draft
        }
      end

      @client.tags(repo).each do |tag|
        next if tag.name =~ /^sprint-/

        commit = @commits.fetch(tag.commit.sha, {})
        semantic = !(tag.name =~ /^\d+\.\d+\.\d+$/).nil?
        release = @releases.fetch(tag.name, {})

        next if commit.empty?

        has_release = !release.empty?
        has_artifact = artifacts.key?(tag.name)
        has_image = ecrimages.key?(tag.name)

        @cssclasses = [
          'data',
          semantic ? 'semantic' : 'other'
        ]
        @cssclasses << 'no-release' unless has_release
        @cssclasses << 'no-artifact' unless has_artifact
        @cssclasses << 'no-image' unless has_image

        actions = []
        actions << {
          value: 'Deploy Dev',
          href: NOACT,
          cssclass: 'button-disabled',
          disabled: true
        }
        if has_artifact
          actions << {
            value: 'Delete Artifacts',
            href: NOACT,
            cssclass: 'buttontbd',
            disabled: false
          }
        end

        if has_image
          actions << {
            value: 'Delete Images',
            href: NOACT,
            cssclass: 'buttontbd',
            disabled: false
          }
        end

        @tags[tag.name] = {
          cssclass: @cssclasses.join(' '),
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
          release: {
            value: has_release ? release.fetch(:name, '') : 'Create',
            href: has_release ? release.fetch(:url, '') : "https://github.com/#{repo}/releases/new?tag=#{tag.name}",
            cssclass: if has_release
                        release.fetch(:draft, false) ? 'draft' : ''
                      else
                        'button'
                      end
          },
          artifacts: has_artifact ? artifacts.fetch(tag.name, []) : '',
          images: has_image ? ecrimages.fetch(tag.name, []) : '',
          actions: actions
        }
      end

      tags.each_value do |data|
        table.add_row(
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
      table
    end

    def tags
      @tags.sort_by { |_k, v| v[:date] }.reverse.to_h
    rescue StandardError
      @tags.sort_by { |k, _v| k }.reverse.to_h
    end
  end
end
