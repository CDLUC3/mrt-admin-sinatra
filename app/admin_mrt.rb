# frozen_string_literal: true

require 'sinatra'
require 'sinatra/base'
require 'sinatra/contrib'
require_relative 'lib/routes/home'
require_relative 'lib/routes/code'
require_relative 'lib/routes/resources'
require_relative 'lib/routes/services'
require_relative 'lib/routes/query'
require_relative 'lib/routes/ldap'
require_relative 'lib/routes/mrtzk'

set :bind, '0.0.0.0'

include Sinatra::UC3HomeRoutes
include Sinatra::UC3CodeRoutes
include Sinatra::UC3ResourcesRoutes
include Sinatra::UC3ServicesRoutes
include Sinatra::UC3QueryRoutes
include Sinatra::UC3LdapRoutes

Sinatra::UC3HomeRoutes.load_menu_file('app/config/mrt/menu.yml')
AdminUI::Context.css = '/mrt/custom.css'
AdminUI::Context.index_md = 'app/markdown/mrt/index.md'

register Sinatra::Contrib

def adminui_show_table_format(context, table, format)
  if format == 'json'
    content_type :json
    {
      context: context.to_h,
      table: table.table_data
    }.to_json
  elsif format == 'csv'
    content_type :text
    halt 200, {'Content-Type' => 'text/csv'}, table.to_csv
  else
    erb :table,
      :layout => :page_layout,
      :locals => {
        context: context,
        table: table
      }
  end
end

def adminui_show_table(context, table)
  fmt = request.params.fetch('format', '')
  adminui_show_table_format(context, table, fmt) unless fmt.empty?
  respond_to do |format|
    format.json do
      adminui_show_table_format(context, table, 'json')
    end
    format.html do
      adminui_show_table_format(context, table, 'html')
    end
  end
end

def adminui_show_markdown(context, md_file)
  respond_to do |format|
    format.html do
      erb :markdown,
        :layout => :page_layout,
        :locals => {
          md_file: md_file,
          context: context
        }
    end
    format.json do
      content_type :json
      {
        context: context.to_h,
        markdown: md_file
      }.to_json
    end
  end
end

def adminui_show_none(context)
  respond_to do |format|
    format.html do
      erb :none,
        :layout => :page_layout,
        :locals => {
          context: context
        }
    end
    format.json do
      content_type :json
      {
        context: context.to_h
      }.to_json
    end
  end
end

get '/' do
  adminui_show_markdown(
    AdminUI::Context.new(request.path),
    AdminUI::Context.index_md
  )
end

get '/context' do
  adminui_show_table(
    AdminUI::Context.new(request.path),
    UC3::UC3Client.new.context
  )
end

get '/clients' do
  UC3::UC3Client.new
  UC3::FileSystemClient.client
  UC3Query::QueryClient.client
  UC3Queue::ZKClient.client
  UC3Code::SourceCodeClient.client
  UC3Resources::InstancesClient.new
  UC3Resources::ParametersClient.new
  UC3Resources::ServicesClient.new
  UC3Resources::BucketsClient.new
  UC3Resources::FunctionsClient.new
  UC3Resources::LoadBalancerClient.new
  UC3Ldap::LDAPClient.client
  UC3::TestClient.client

  adminui_show_table(
    AdminUI::Context.new(request.path),
    UC3::UC3Client.new.client_list
  )
end

get '/clients-vpc' do
  UC3Query::QueryClient.client
  UC3Queue::ZKClient.client

  adminui_show_table(
    AdminUI::Context.new(request.path),
    UC3::UC3Client.new.client_list
  )
end

get '/infra/clients-no-vpc' do
  UC3Code::SourceCodeClient.new
  UC3Resources::InstancesClient.new
  UC3Resources::ParametersClient.new
  UC3Resources::BucketsClient.new
  UC3Resources::FunctionsClient.new
  UC3Resources::LoadBalancerClient.new

  adminui_show_table(
    AdminUI::Context.new(request.path),
    UC3::UC3Client.new.client_list
  )
end

get '/ops/collections/**' do
  adminui_show_markdown(
    AdminUI::Context.new(request.path),
    'app/markdown/mrt/collections.md'
  )
end

get '/ops/storage/scans' do
  adminui_show_markdown(
    AdminUI::Context.new(request.path),
    'app/markdown/mrt/storage_scans.md'
  )
end

get '/**' do
  adminui_show_none(
    AdminUI::Context.new(request.path)
  )
end

post '/hello' do
  content_type :json
  { message: 'Hello' }.to_json
end
