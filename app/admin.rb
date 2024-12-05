require 'sinatra'
require 'sinatra/base'
require_relative 'lib/merritt.rb'
require_relative 'lib/git.rb'

set :bind, '0.0.0.0'

merritt = Merritt.new

get "/" do
  status 200

  erb :index, :locals => {repos: merritt.repos.keys}
end

get "/git/*" do |repo|
  erb :git, :locals => {git: Github.new(merritt.repo(repo))}
end
