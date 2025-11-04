# frozen_string_literal: true

require 'sinatra'
require 'sinatra/base'
require 'sinatra/contrib'
require_relative 'admin_common'
require_relative 'lib/routes/home'
require_relative 'lib/routes/code'
require_relative 'lib/routes/resources'
require_relative 'lib/routes/services'
require_relative 'lib/routes/query'
require_relative 'lib/routes/ldap'
require_relative 'lib/routes/mrtzk'
require_relative 'lib/routes/config'

set :bind, '0.0.0.0'

include Sinatra::UC3HomeRoutes
include Sinatra::UC3CodeRoutes
include Sinatra::UC3ResourcesRoutes
include Sinatra::UC3ServicesRoutes
include Sinatra::UC3QueryRoutes
include Sinatra::UC3LdapRoutes
include Sinatra::UC3S3Routes

Sinatra::UC3HomeRoutes.load_menu_file('app/config/mrt/menu.yml')
AdminUI::Context.css = '/mrt/custom.css'
AdminUI::Context.index_md = 'app/markdown/mrt/index.md'

register Sinatra::Contrib

get '/' do
  adminui_show_markdown(
    AdminUI::Context.new(request.path, request.params, show_formats: false),
    AdminUI::Context.index_md
  )
end

get '/context' do
  adminui_show_table(
    AdminUI::Context.new(request.path, request.params),
    UC3::UC3Client.client.context
  )
end

get '/clients' do
  begin
    puts "Init UC3Client #{Time.now}"
    UC3::UC3Client.client
    puts "Init FileSystemClient #{Time.now}"
    UC3::FileSystemClient.client
    puts "Init QueryClient #{Time.now}"
    UC3Query::QueryClient.client
    puts "Init ZKClient #{Time.now}"
    UC3Queue::ZKClient.client
    puts "Init SourceCodeClient #{Time.now}"
    UC3Code::SourceCodeClient.client
    puts "Init InstancesClient #{Time.now}"
    UC3Resources::InstancesClient.client
    puts "Init ParametersClient #{Time.now}"
    UC3Resources::ParametersClient.client
    puts "Init ServicesClient #{Time.now}"
    UC3Resources::ServicesClient.client
    puts "Init BucketsClient #{Time.now}"
    UC3Resources::BucketsClient.client
    puts "Init FunctionsClient #{Time.now}"
    UC3Resources::FunctionsClient.client
    puts "Init LoadBalancerClient #{Time.now}"
    UC3Resources::LoadBalancerClient.client
    puts "Init LDAPClient #{Time.now}"
    UC3Ldap::LDAPClient.client
    puts "Init ConfigObjectsClient #{Time.now}"
    UC3S3::ConfigObjectsClient.client
    puts "Init TestClient #{Time.now}"
    UC3::TestClient.client
  rescue StandardError => e
    puts "Error initializing clients: #{e.message}"
    puts e.backtrace.join("\n")
  end

  adminui_show_table(
    AdminUI::Context.new(request.path, request.params),
    UC3::UC3Client.client.client_list
  )
end

get '/**' do
  adminui_show_none(
    AdminUI::Context.new(request.path, request.params, show_formats: false)
  )
end

post '/hello' do
  content_type :json
  { message: 'Hello' }.to_json
end
