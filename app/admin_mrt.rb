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
require_relative 'lib/routes/metrics'
require_relative 'lib/routes/opensearch'

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
  supp = UC3S3::ConfigObjectsClient.client.get_doc_page('support.md')

  if supp.empty?
    fname = "app/markdown/mrt/#{UC3::UC3Client.stack_name}.md"
    if File.exist?(fname)
      adminui_show_markdown(
        AdminUI::Context.new(request.path, request.params, show_formats: false),
        fname
      )
    else
      adminui_show_markdown(
        AdminUI::Context.new(request.path, request.params, show_formats: false),
        AdminUI::Context.index_md
      )
    end
  else
    adminui_show_markdown_text(
      AdminUI::Context.new(request.path, request.params, show_formats: false),
      supp
    )
  end
end

get '/context' do
  adminui_show_table(
    AdminUI::Context.new(request.path, request.params),
    UC3::UC3Client.client.context
  )
end

get '/clients' do
  begin
    Sinatra::Application.logger.debug("Init UC3Client #{Time.now}")
    UC3::UC3Client.client
    Sinatra::Application.logger.debug("Init FileSystemClient #{Time.now}")
    UC3::FileSystemClient.client
    Sinatra::Application.logger.debug("Init QueryClient #{Time.now}")
    UC3Query::QueryClient.client
    Sinatra::Application.logger.debug("Init ZKClient #{Time.now}")
    UC3Queue::ZKClient.client
    Sinatra::Application.logger.debug("Init SourceCodeClient #{Time.now}")
    UC3Code::SourceCodeClient.client
    Sinatra::Application.logger.debug("Init InstancesClient #{Time.now}")
    UC3Resources::InstancesClient.client
    Sinatra::Application.logger.debug("Init ParametersClient #{Time.now}")
    UC3Resources::ParametersClient.client
    Sinatra::Application.logger.debug("Init ServicesClient #{Time.now}")
    UC3Resources::ServicesClient.client
    Sinatra::Application.logger.debug("Init BucketsClient #{Time.now}")
    UC3Resources::BucketsClient.client
    Sinatra::Application.logger.debug("Init FunctionsClient #{Time.now}")
    UC3Resources::FunctionsClient.client
    Sinatra::Application.logger.debug("Init LoadBalancerClient #{Time.now}")
    UC3Resources::LoadBalancerClient.client
    Sinatra::Application.logger.debug("Init LDAPClient #{Time.now}")
    UC3Ldap::LDAPClient.client
    Sinatra::Application.logger.debug("Init ConfigObjectsClient #{Time.now}")
    UC3S3::ConfigObjectsClient.client
    Sinatra::Application.logger.debug("Init OSClient #{Time.now}")
    UC3OpenSearch::OSClient.client
    Sinatra::Application.logger.debug("Init TestClient #{Time.now}")
    UC3::TestClient.client
  rescue StandardError => e
    Sinatra::Application.logger.error("Error initializing clients: #{e.message}")
    Sinatra::Application.logger.error(e.backtrace.join("\n"))
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
