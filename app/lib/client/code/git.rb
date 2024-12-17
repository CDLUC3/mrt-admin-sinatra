# frozen_string_literal: true

require 'octokit'
require 'aws-sdk-ssm'
require_relative '../../ui/table'
require_relative '../uc3_client'

# export GHTOKEN=pull from SSM /uc3/mrt/dev/github/readonly

# Scope custom code for UC3 to distinguish from 3rd party classes
module UC3Code
  Octokit.configure do |c|
    c.auto_paginate = true
  end

  # Query for github repository tags
  class GithubClient < UC3::UC3Client
    NOACT = 'javascript:alert("Not yet implemented");'
    def initialize
      super
      token = '' # TBD
      opts = {}
      opts[:access_token] = token unless token.empty?
      begin
        @client = Octokit::Client.new(opts)
      rescue StandardError => e
        puts e
      end
      @tags = {}
      @since = Time.now - (2 * 365 * 24 * 60 * 60)
    end

    def enabled
      !@client.nil?
    end

    attr_accessor :repo, :commits, :table

    def make_table
      AdminUI::FilterTable.new(
        # Tag	Date	Commit Sha	Documented Release	Artifacts	ECR Images	Actions
        columns: [
          AdminUI::Column.new(:tag, header: 'Tag', cssclass: 'tag'),
          AdminUI::Column.new(:date, header: 'Date', cssclass: 'date'),
          AdminUI::Column.new(:sha, header: 'Commit Sha', cssclass: 'sha'),
          AdminUI::Column.new(:release, header: 'Documented Release', cssclass: 'release'),
          AdminUI::Column.new(:artifacts, header: 'Artifacts', cssclass: 'artifacts'),
          AdminUI::Column.new(:images, header: 'ECR Images', cssclass: 'images'),
          AdminUI::Column.new(:actions, header: 'Actions', cssclass: 'actions', spanclass: '')
        ],
        filters: [
          AdminUI::Filter.new('Semantic Tags Only', 'other'),
          AdminUI::Filter.new('Has Release', 'no-release'),
          AdminUI::Filter.new('Has Artifact', 'no-artifact'),
          AdminUI::Filter.new('Has Image', 'no-image')
        ]
      )
    end

    def get_commits(repo)
      commits = {}
      @client.commits_since(repo, @since).each do |commit|
        commits[commit.sha] = {
          sha: commit.sha,
          message: commit.commit.message,
          author: commit.commit.author.name,
          date: commit.commit.author.date,
          url: commit.html_url
        }
      end
      commits
    end

    def get_releases(repo)
      releases = {}
      @client.releases(repo).each do |rel|
        releases[rel.tag_name] = {
          tag: rel.tag_name,
          name: rel.name,
          url: rel.html_url,
          draft: rel.draft
        }
      end
      releases
    end

    def semantic_tag?(tag)
      !(tag =~ /^\d+\.\d+\.\d+$/).nil?
    end

    def css_classes(tag, _commit, release, tagartifacts, tagimages)
      cssclasses = [
        'data',
        semantic_tag?(tag) ? 'semantic' : 'other'
        ]
      cssclasses << 'no-release' if release.empty?
      cssclasses << 'no-artifact' if tagartifacts.empty?
      cssclasses << 'no-image' if tagimages.empty?
      cssclasses
    end

    def actions(_tag, _commit, _release, tagartifacts, tagimages)
      actions = []
      actions << {
        value: 'Deploy Dev',
        href: NOACT,
        cssclass: 'button-disabled',
        disabled: true
      }
      unless tagartifacts.empty?
        actions << {
          value: 'Delete Artifacts',
          href: NOACT,
          cssclass: 'buttontbd',
          disabled: false
        }
      end

      unless tagimages.empty?
        actions << {
          value: 'Delete Images',
          href: NOACT,
          cssclass: 'buttontbd',
          disabled: false
        }
      end
      actions
    end

    def make_sha(tag, commit)
      [
        {
          value: tag.commit.sha,
          href: commit.fetch(:url, '')
        },
        commit.fetch(:message, ''),
        commit.fetch(:author, '')
      ]
    end

    def make_release(repo, tag, release)
      if release.empty?
        {
          value: 'Create',
          href: "https://github.com/#{repo}/releases/new?tag=#{tag.name}",
          cssclass: 'button'
        }
      else
        {
          value: release.fetch(:name, ''),
          href: release.fetch(:url, ''),
          cssclass: release.fetch(:draft, false) ? 'draft' : ''
        }
      end
    end

    def list_tags(repohash: {}, artifacts: {}, ecrimages: {})
      repo = repohash.fetch(:repo, '')

      @tags = {}
      table = make_table
      commits = get_commits(repo)
      releases = get_releases(repo)

      @client.tags(repo).each do |tag|
        next if tag.name =~ /^sprint-/

        commit = commits.fetch(tag.commit.sha, {})
        next if commit.empty?

        tagrelease = releases.fetch(tag.name, {})
        tagartifacts = artifacts.fetch(tag.name, [])
        tagimages = ecrimages.fetch(tag.name, [])

        @tags[tag.name] = {
          cssclass: css_classes(tag.name, commit, tagrelease, tagartifacts, tagimages).join(' '),
          tag: tag.name,
          date: commit.fetch(:date, ''),
          sha: make_sha(tag, commit),
          release: make_release(repo, tag, tagrelease),
          artifacts: tagartifacts,
          images: tagimages,
          actions: actions(tag.name, commit, tagrelease, tagartifacts, tagimages)
        }
      end

      tags.each_value do |data|
        table.add_row(
          AdminUI::Row.make_row(table.columns, data)
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
