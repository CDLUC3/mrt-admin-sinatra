require 'json'
require 'yaml'

class Merritt
  def initialize
    config = YAML.safe_load_file('merritt.yml', aliases: true)
    @repos = JSON.parse(config.to_json, symbolize_names: true).fetch(:repos, {})
  end

  attr_accessor :repos

  def repo(repo)
    @repos.fetch(repo.to_sym, {})
  end
end