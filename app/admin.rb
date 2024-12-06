require 'sinatra'
require 'sinatra/base'
require_relative 'lib/merritt.rb'
require_relative 'lib/git.rb'

set :bind, '0.0.0.0'

merritt = Merritt.new

get "/" do
  status 200

  erb :index, 
    :layout => :page_layout, 
    :locals => {
      title: 'Merritt Admin Tool - UC3 Account',
      repos: merritt.repos.keys
    }
end

get "/git/*" do |repo|
  repodata = merritt.repo(repo)
  erb :git, 
    :layout => :page_layout, 
    :locals => {
      title: "Repo Tags: #{repodata.fetch(:repo, repo)}",
      git: Github.new(repodata)
    }
end
