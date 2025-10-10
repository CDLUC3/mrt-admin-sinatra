# frozen_string_literal: true

require 'sinatra'
require 'sinatra/base'
require 'sinatra/contrib'
require_relative 'admin_common'
require_relative 'lib/routes/home'
require_relative 'lib/routes/resources'
require_relative 'lib/routes/query'

set :bind, '0.0.0.0'

include Sinatra::UC3HomeRoutes
include Sinatra::UC3ResourcesRoutes

Sinatra::UC3HomeRoutes.load_menu_file('app/config/uc3/menu.yml')
AdminUI::Context.css = '/uc3/custom.css'
AdminUI::Context.index_md = 'app/markdown/uc3/index.md'

get '/' do
  adminui_show_markdown(
    AdminUI::Context.new(request.path),
    AdminUI::Context.index_md
  )
end

get '/context' do
  erb :table,
    :layout => :page_layout,
    :locals => {
      context: AdminUI::Context.new(request.path),
      table: UC3::UC3Client.client.context
    }
end

get '/clients' do
  UC3Resources::InstancesClient.new
  UC3Resources::ParametersClient.new
  UC3Resources::BucketsClient.new
  UC3Resources::FunctionsClient.new
  UC3Resources::LoadBalancerClient.new

  erb :table,
    :layout => :page_layout,
    :locals => {
      context: AdminUI::Context.new(request.path),
      table: UC3::UC3Client.client.client_list
    }
end

get '/**' do
  erb :none,
    :layout => :page_layout,
    :locals => {
      context: AdminUI::Context.new(request.path)
    }
end
