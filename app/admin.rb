# frozen_string_literal: true

require 'sinatra'
require 'sinatra/base'
require_relative 'lib/routes/code'
require_relative 'lib/routes/resources'

set :bind, '0.0.0.0'

include Sinatra::UC3CodeRoutes
include Sinatra::UC3ResourcesRoutes

AdminUI::Context.add_menu_item(AdminUI::MENU_HOME, 'Home')
AdminUI::Context.add_menu_item(AdminUI::MENU_HOME, 'Admin Tool Home', AdminUI::MENU_ROOT)
get '/' do
  erb :index,
    :layout => :page_layout,
    :locals => {
      context: AdminUI::Context.new(request.path)
    }
end

AdminUI::Context.add_menu_item(AdminUI::MENU_HOME, 'Admin Tool Context', '/context')
get '/context' do
  erb :table,
    :layout => :page_layout,
    :locals => {
      context: AdminUI::Context.new(request.path),
      table: UC3::UC3Client.new.context
    }
end

AdminUI::Context.add_menu_item(AdminUI::MENU_HOME, 'Admin Tool Clients', '/clients')
get '/clients' do
  UC3Code::SourceCodeClient.new
  UC3Resources::InstancesClient.new
  UC3Resources::ParametersClient.new

  erb :table,
    :layout => :page_layout,
    :locals => {
      context: AdminUI::Context.new(request.path),
      table: UC3::UC3Client.new.clients
    }
end