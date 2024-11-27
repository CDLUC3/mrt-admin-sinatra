require 'sinatra'
require 'sinatra/base'
require_relative 'lib/git.rb'

set :bind, '0.0.0.0'

get "/" do
  status 200

  erb :index
end

get "/git/*" do |repo|
  erb :git, :locals => {git: Github.new(repo)}
end
