# frozen_string_literal: true

require 'json'
require 'yaml'
require_relative 'git'
require_relative 'codeartifact'
require_relative 'ecr_images'
require_relative '../uc3_client'

# Scope custom code for UC3 to distinguish from 3rd party classes
module UC3Code
  # Load clients for retrieving source code information
  class SourceCodeClient < UC3::UC3Client
    def initialize
      @repos = load_config('app/config/source_code.yml').fetch(:repos, {})
      @github = UC3Code::GithubClient.new
      @codeartifact = UC3Code::CodeArtifactClient.new
      @ecrimages = UC3Code::ECRImagesClient.new
      super
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
