# frozen_string_literal: true

require 'sinatra'
require 'sinatra/base'
require_relative 'lib/routes/code'
require_relative 'lib/routes/resources'
require_relative 'lib/routes/query'

set :bind, '0.0.0.0'

include Sinatra::UC3CodeRoutes
include Sinatra::UC3ResourcesRoutes
include Sinatra::UC3QueryRoutes

menu_home = AdminUI::Context.topmenu.add_submenu(AdminUI::MENU_HOME, 'Home')

menu_home.add_menu_item(AdminUI::MENU_ROOT, 'Admin Tool Home')

AdminUI::Context.topmenu.create_menu_for_path('/test', 'Test')
AdminUI::Context.topmenu.create_menu_for_path('/test/aaa', 'AAA')
AdminUI::Context.topmenu.create_menu_item_for_path('/test/aaa', '/test?aaa', 'Test AAA')
AdminUI::Context.topmenu.create_menu_item_for_path('/test/bbb', '/test?bbb', 'Test BBB')
AdminUI::Context.topmenu.create_menu_item_for_path('/test/ccc', '/test?ccc', 'Test DDD')

(1..40).each do |i|
  AdminUI::Context.topmenu.create_menu_item_for_path('/test/ccc', "/test?ccc#{i}", "Test DDD #{i}")
end

get '/' do
  erb :index,
    :layout => :page_layout,
    :locals => {
      context: AdminUI::Context.new(request.path)
    }
end

menu_home.add_menu_item('/context', 'Admin Tool Context')
get '/context' do
  erb :table,
    :layout => :page_layout,
    :locals => {
      context: AdminUI::Context.new(request.path),
      table: UC3::UC3Client.new.context
    }
end

menu_home.add_menu_item('/clients', 'Admin Tool Clients')
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
