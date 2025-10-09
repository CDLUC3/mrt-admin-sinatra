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

def adminui_show_table_format(context, table, format, erb: :table, locals: {})
  halt 404, 'Not Found' if table.nil?

  case format
  when 'json'
    content_type :json
    {
      context: context.to_h,
      table: table.table_data,
      status: table.status,
      status_message: table.status_message
    }.to_json
  when 'csv'
    fname = "mrt-admin#{context.route.gsub('/', '-')}.#{Time.now.strftime('%Y%m%d-%H%M%S')}.csv"
    content_type :text
    halt 200, { 'Content-Type' => 'text/csv', 'Content-Disposition' => "attachment; filename=\"#{fname}\"" },
      table.to_csv
  when 'text'
    content_type :text
    halt 200, table.to_csv
  else
    locals[:context] = context
    locals[:table] = table
    erb erb,
      :layout => :page_layout,
      :locals => locals
  end
end

def adminui_show_table(context, table, erb: :table, locals: {})
  fmt = request.params.fetch('admintoolformat', '')
  adminui_show_table_format(context, table, fmt, erb: erb, locals: locals) unless fmt.empty?
  respond_to do |format|
    format.json do
      adminui_show_table_format(context, table, 'json', erb: erb, locals: locals)
    end
    format.html do
      adminui_show_table_format(context, table, 'html', erb: erb, locals: locals)
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
    AdminUI::Context.new(request.path),
    UC3::UC3Client.client.client_list
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
