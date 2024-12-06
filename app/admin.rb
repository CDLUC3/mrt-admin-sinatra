require 'sinatra'
require 'sinatra/base'
require_relative 'lib/merritt.rb'
require_relative 'lib/context.rb'

set :bind, '0.0.0.0'

merritt = Merritt.new

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
  repodata = merritt.repo(repo)
  erb :git, 
    :layout => :page_layout, 
    :locals => {
      context: Context.new("Repo Tags: #{repodata.repo}"),
      git: repodata
    }
end
