require 'sinatra'
require 'sinatra/base'
require_relative 'lib/config/merritt.rb'
require_relative 'lib/ui/context.rb'

set :bind, '0.0.0.0'

merritt = MerrittConfig.new

get "/" do
  status 200

  erb :index, 
    :layout => :page_layout, 
    :locals => {
      context: Context.new('Merritt Admin Tool - UC3 Account', top_page: true),
      repos: merritt.repos.keys
    }
end

get "/git/*" do |repo|
  artifacts = merritt.codeartifact(repo).list_package_versions
  ecrimages = merritt.ecrimages(repo).list_image_tags
  repodata = merritt.repo(repo, artifacts: artifacts, ecrimages: ecrimages)
  erb :git, 
    :layout => :page_layout, 
    :locals => {
      context: Context.new("Repo Tags: #{repodata.repo}"),
      git: repodata,
      table: repodata.table
    }
end
