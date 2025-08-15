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
      map = UC3::UC3Client.lookup_map_by_filename(
        'app/config/mrt/source.lookup.yml',
        key: ENV.fetch('configkey', 'default')
      )

      token = map.fetch('token', '')
      opts = {}
      opts[:access_token] = token unless token.empty?
      begin
        @client = Octokit::Client.new(opts)
      rescue StandardError => e
        puts "GitHub client error #{e}"
      end
      @tags = {}
      @since = Time.now - (2 * 365 * 24 * 60 * 60)
      super(enabled: enabled)
    end

    def enabled
      !@client.nil?
    end

    attr_accessor :repo, :commits, :table

    def make_table
      AdminUI::FilterTable.new(
        # Tag	Date	Commit Sha	Documented Release	Artifacts	ECR Images	Actions
        columns: [
          AdminUI::Column.new(:tag, header: 'Git Tag', cssclass: 'tag'),
          AdminUI::Column.new(:date, header: 'Date', cssclass: 'date'),
          AdminUI::Column.new(:sha, header: 'Commit Sha', cssclass: 'sha'),
          AdminUI::Column.new(:release, header: 'Documented Release', cssclass: 'release'),
          AdminUI::Column.new(:artifacts, header: 'Artifacts', cssclass: 'artifacts'),
          AdminUI::Column.new(:images, header: 'ECR Images', cssclass: 'images'),
          AdminUI::Column.new(:matching_tags, header: 'Matching Image Tags'),
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
      @client.branches(repo).each do |branch|
        @client.commits_since(repo, @since, sha: branch.name).each do |commit|
          commits[commit.sha] = {
            sha: commit.sha,
            message: commit.commit.message,
            author: commit.commit.author.name,
            date: commit.commit.author.date,
            url: commit.html_url
          }
        end
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

    def css_classes(tag, _commit, release, tagartifacts, tagimages)
      cssclasses = [
        'data',
        UC3::UC3Client.semantic_tag?(tag) ? 'semantic' : 'other'
      ]
      cssclasses << 'no-release' if release.empty?
      cssclasses << 'no-artifact' if tagartifacts.empty?
      cssclasses << 'no-image' if tagimages.empty?
      cssclasses
    end

    def actions(_repohash, tag, _commit, release, tagartifacts, tagimages, deployed, matching_tags)
      actions = []
      unless tagartifacts.empty? || deployed
        actions << {
          value: 'Delete Artifacts',
          href: "/source/artifacts/delete/#{tag}",
          cssclass: 'button',
          post: true,
          disabled: false,
          data: tagartifacts.join("\n")
        }
      end

      unless tagimages.empty?
        unless deployed
          actions << {
            value: 'Delete Images',
            href: "/source/images/delete/#{tag}",
            cssclass: 'button',
            post: true,
            disabled: false,
            data: tagimages.join("\n")
          }
        end

        actions << if matching_tags.include?(TAG_ECS_DEV)
                     {
                       value: "Untag #{TAG_ECS_DEV}",
                       href: "/source/images/untag/#{TAG_ECS_DEV}",
                       cssclass: 'button',
                       post: true,
                       disabled: false,
                       data: tagimages.join("\n")
                     }
                   else
                     {
                       value: "Tag #{TAG_ECS_DEV}",
                       href: "/source/images/retag/#{tag}/#{TAG_ECS_DEV}",
                       cssclass: 'button',
                       post: true,
                       disabled: false,
                       data: tagimages.join("\n")
                     }
                   end

        if matching_tags.include?(TAG_ECS_STG)
          actions << {
            value: "Untag #{TAG_ECS_STG}",
            href: "/source/images/untag/#{TAG_ECS_STG}",
            cssclass: 'button',
            post: true,
            disabled: false,
            data: tagimages.join("\n")
          }
        elsif UC3::UC3Client.semantic_prefix_tag?(tag)
          actions << {
            value: "Tag #{TAG_ECS_STG}",
            href: "/source/images/retag/#{tag}/#{TAG_ECS_STG}",
            cssclass: 'button',
            post: true,
            disabled: false,
            data: tagimages.join("\n")
          }
        end

        if matching_tags.include?(TAG_ECS_PRD)
          actions << {
            value: "Untag #{TAG_ECS_PRD}",
            href: "/source/images/untag/#{TAG_ECS_PRD}",
            cssclass: 'button',
            post: true,
            disabled: false,
            data: tagimages.join("\n")
          }
        elsif UC3::UC3Client.semantic_tag?(tag) && !release.empty?
          actions << {
            value: "Tag #{TAG_ECS_PRD}",
            href: "/source/images/retag/#{tag}/#{TAG_ECS_PRD}",
            cssclass: 'button',
            post: true,
            disabled: false,
            data: tagimages.join("\n")
          }
        end
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
        tagimagerecs = ecrimages.fetch(tag.name, [])
        tagimages = []
        deployed = false
        matching_tags = []
        tagimagerecs.each do |tagrec|
          tagimages << tagrec.fetch(:image, '') unless tagrec.fetch(:image, '').empty?
          deployed |= tagrec.fetch(:deployed, false)
          matching_tags << tagrec.fetch(:matching_tags, '') unless tagrec.fetch(:matching_tags, '').empty?
          matching_tags.flatten!
        end

        next unless UC3::UC3Client.semantic_prefix_tag?(tag.name) || !tagartifacts.empty? || !tagimages.empty?

        @tags[tag.name] = {
          cssclass: css_classes(tag.name, commit, tagrelease, tagartifacts, tagimages).join(' '),
          tag: tag.name,
          date: commit.fetch(:date, ''),
          sha: make_sha(tag, commit),
          release: make_release(repo, tag, tagrelease),
          artifacts: tagartifacts,
          images: tagimages,
          matching_tags: matching_tags,
          actions: actions(repohash, tag.name, commit, tagrelease, tagartifacts, tagimages, deployed, matching_tags)
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
