require 'json'
require 'yaml'
require_relative '../api/git.rb'

class Merritt
  def initialize
    config = YAML.safe_load_file('app/config/merritt.yml', aliases: true)
    @repos = JSON.parse(config.to_json, symbolize_names: true).fetch(:repos, {})
  end

  attr_accessor :repos

  def repo(repo)
    repodata = @repos.fetch(repo.to_sym, {})
    return nil if repodata.empty?
    Github.new(repodata)
  end
end