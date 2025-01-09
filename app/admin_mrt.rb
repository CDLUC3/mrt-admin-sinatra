# frozen_string_literal: true

require 'sinatra'
require 'sinatra/base'
require_relative 'lib/routes/home'
require_relative 'lib/routes/code'
require_relative 'lib/routes/resources'
require_relative 'lib/routes/query'

set :bind, '0.0.0.0'

include Sinatra::UC3HomeRoutes
include Sinatra::UC3CodeRoutes
include Sinatra::UC3ResourcesRoutes
include Sinatra::UC3QueryRoutes

Sinatra::UC3HomeRoutes.load_menu_file('app/config/mrt/menu.yml')
AdminUI::Context.css = '/mrt/merritt.css'
AdminUI::Context.navcss = '/mrt/navmenu.css'
AdminUI::Context.index_md = 'app/markdown/mrt/index.md'

get '/' do
  erb :index,
    :layout => :page_layout,
    :locals => {
      context: AdminUI::Context.new(request.path)
    }
end

get '/context' do
  erb :table,
    :layout => :page_layout,
    :locals => {
      context: AdminUI::Context.new(request.path),
      table: UC3::UC3Client.new.context
    }
end

get '/clients' do
  UC3Code::SourceCodeClient.new
  UC3Resources::InstancesClient.new
  UC3Resources::ParametersClient.new
  UC3Resources::BucketsClient.new
  UC3Resources::FunctionsClient.new
  UC3Resources::LoadBalancerClient.new
  UC3Query::QueryClient.client

  erb :table,
    :layout => :page_layout,
    :locals => {
      context: AdminUI::Context.new(request.path),
      table: UC3::UC3Client.new.client_list
    }
end

get '/objects/**' do
  erb 'mrt/objects'.to_sym,
    :layout => :page_layout,
    :locals => {
      context: AdminUI::Context.new(request.path)
    }
end

get '/collections/**' do
  erb 'mrt/collections'.to_sym,
    :layout => :page_layout,
    :locals => {
      context: AdminUI::Context.new(request.path)
    }
end

get '/storage_scans' do
  erb 'mrt/storage_scans'.to_sym,
    :layout => :page_layout,
    :locals => {
      context: AdminUI::Context.new(request.path)
    }
end

get '/**' do
  erb :none,
    :layout => :page_layout,
    :locals => {
      context: AdminUI::Context.new(request.path)
    }
end
