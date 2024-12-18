# frozen_string_literal: true

require 'sinatra'
require 'sinatra/base'
require_relative 'lib/routes/code'
require_relative 'lib/routes/resources'

set :bind, '0.0.0.0'

include Sinatra::UC3CodeRoutes
include Sinatra::UC3ResourcesRoutes

get '/' do
  status 200

  erb :index,
    :layout => :page_layout,
    :locals => {
      context: AdminUI::Context.new('Merritt Admin Tool - UC3 Account', top_page: true)
    }
end

get '/context' do
  erb :table,
    :layout => :page_layout,
    :locals => {
      context: AdminUI::Context.new("Admin Tool Context"),
      table: UC3::UC3Client.new.context
    }
end

get '/clients' do
  UC3Code::SourceCodeClient.new
  UC3Resources::InstancesClient.new
  UC3Resources::ParametersClient.new

  erb :table,
    :layout => :page_layout,
    :locals => {
      context: AdminUI::Context.new("Admin Tool Clients"),
      table: UC3::UC3Client.new.clients
    }
end