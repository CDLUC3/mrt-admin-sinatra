require 'json'
require 'yaml'
require_relative '../api/git.rb'
require_relative '../api/codeartifact.rb'
require_relative '../api/ecr_images.rb'

class MerrittConfig
  def initialize
    config = YAML.safe_load_file('app/config/merritt.yml', aliases: true)
    @repos = JSON.parse(config.to_json, symbolize_names: true).fetch(:repos, {})
  end

  attr_accessor :repos

  def repo(repo, artifacts: {}, ecrimages: {})
    repodata = @repos.fetch(repo.to_sym, {})
    return nil if repodata.empty?
    gitdata = UC3::GithubClient.new(repodata, artifacts: artifacts, ecrimages: ecrimages)
    gitdata
  end

  def codeartifact(repo)
    repodata = @repos.fetch(repo.to_sym, {})
    return nil if repodata.empty?
    UC3::CodeArtifactClient.new(repodata)
  end

  def ecrimages(repo)
    repodata = @repos.fetch(repo.to_sym, {})
    return nil if repodata.empty?
    UC3::ECRImagesClient.new(repodata)
  end
end