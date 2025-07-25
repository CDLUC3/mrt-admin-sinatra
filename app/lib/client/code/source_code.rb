# frozen_string_literal: true

require 'json'
require 'yaml'
require 'rubygems'
require_relative 'git'
require_relative 'codeartifact'
require_relative 'ecr_images'
require_relative '../uc3_client'
require_relative '../../ui/table'

# Scope custom code for UC3 to distinguish from 3rd party classes
module UC3Code
  TAG_ECS_DEV = 'ecs-dev'
  TAG_ECS_STG = 'ecs-stg'
  TAG_ECS_PRD = 'ecs-prd'

  # Load clients for retrieving source code information
  class SourceCodeClient < UC3::UC3Client
    def self.client
      UC3::UC3Client.clients.fetch(self.class.to_s, SourceCodeClient.new)
    end

    def initialize
      @repos = UC3::UC3Client.load_config('app/config/mrt/source_code.yml').fetch(:repos, {})
      @github = UC3Code::GithubClient.new
      @codeartifact = UC3Code::CodeArtifactClient.new
      @ecrimages = UC3Code::ECRImagesClient.new
      super
    end

    def reponame(repo)
      @repos.fetch(repo.to_sym, {}).fetch(:repo, '')
    end

    def repo_config(repo)
      @repos.fetch(repo.to_sym, {})
    end

    def repo_tags(repo)
      repohash = repo_config(repo)
      return nil if repohash.empty?

      @github.list_tags(
        repohash: repohash,
        artifacts: @codeartifact.list_package_versions(repohash: repohash),
        ecrimages: @ecrimages.list_images(repohash: repohash)
      )
    end

    def reponames
      @repos.keys
    end

    def repos
      table = AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:repo, header: 'Repo'),
          AdminUI::Column.new(:tags, header: 'Tags'),
          AdminUI::Column.new(:artifacts, header: 'Artifacts')
        ]
      )
      @repos.each_key do |repo|
        artifacts = if repo_config(repo).fetch(:artifacts,
          []).empty?
                      {}
                    else
                      { value: repo, href: "/source/artifacts/#{repo}" }
                    end
        table.add_row(
          AdminUI::Row.make_row(
            table.columns,
            {
              repo: repo,
              tags: { value: repo, href: "/source/#{repo}" },
              artifacts: artifacts
            }
          )
        )
      end
      table
    end

    def artifacts(repo)
      repohash = repo_config(repo)
      @codeartifact.list_package_artifacts(repohash: repohash)
    end

    def artifacts_table(repo)
      @codeartifact.artifact_table(artifacts(repo))
    end

    def images(repo)
      repohash = repo_config(repo)
      @ecrimages.list_images(repohash: repohash)
    end

    def images_table(repo)
      @ecrimages.image_table(images(repo))
    end

    def artifact(artifact, version, asset)
      @codeartifact.artifact(artifact, version, asset)
    end

    def artifact_manifest(artifact, version, asset)
      @codeartifact.artifact_manifest(artifact, version, asset)
    end

    def artifact_manifest_table(res)
      @codeartifact.artifact_manifest_table(res)
    end

    def delete_image(tag, image)
      @ecrimages.delete_image(tag, image)
    end

    def retag_image(tag, newtag, image)
      @ecrimages.retag_image(tag, newtag, image)
    end

    def untag_image(tag, image)
      @ecrimages.untag_image(tag, image)
    end

    def delete_artifact(tag, artifact)
      @codeartifact.delete_artifact(tag, artifact)
    end
  end
end
