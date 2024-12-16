# frozen_string_literal: true

require 'json'
require 'yaml'
require_relative 'git'
require_relative 'codeartifact'
require_relative 'ecr_images'
require_relative 'uc3_client'

module UC3
  class SourceCodeClient < UC3Client
    def initialize
      config = YAML.safe_load_file('app/config/source_code.yml', aliases: true)
      @repos = JSON.parse(config.to_json, symbolize_names: true).fetch(:repos, {})
      @github = UC3::GithubClient.new
      @codeartifact = UC3::CodeArtifactClient.new
      @ecrimages = UC3::ECRImagesClient.new
    end

    attr_accessor :repos

    def reponame(repo)
      @repos.fetch(repo.to_sym, {}).fetch(:repo, '')
    end

    def repo_tags(repo)
      repohash = @repos.fetch(repo.to_sym, {})
      return nil if repohash.empty?

      @github.list_tags(
        repohash: repohash,
        artifacts: @codeartifact.list_package_versions(repohash: repohash),
        ecrimages: @ecrimages.list_image_tags(repohash: repohash)
      )
    end
  end
end
