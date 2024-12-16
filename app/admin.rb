# frozen_string_literal: true

require 'sinatra'
require 'sinatra/base'
require_relative 'lib/client/source_code'
require_relative 'lib/ui/context'

set :bind, '0.0.0.0'

srccode = UC3::SourceCodeClient.new

get '/' do
  status 200

  erb :index,
    :layout => :page_layout,
    :locals => {
      context: Context.new('Merritt Admin Tool - UC3 Account', top_page: true),
      repos: srccode.repos.keys
    }
end

get '/git/*' do |repo|
  erb :git,
    :layout => :page_layout,
    :locals => {
      context: Context.new("Repo Tags: #{srccode.reponame(repo)}"),
      table: srccode.repo_tags(repo)
    }
end
