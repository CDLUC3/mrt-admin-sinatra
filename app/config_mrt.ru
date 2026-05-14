# frozen_string_literal: true

require 'rack'
require 'rack/contrib'
require 'logger'
require_relative 'admin_mrt'

set :root, File.dirname(__FILE__)
set :views, proc { File.join(root, 'views') }
set :logger, Logger.new($stdout)
set :logging, Logger::DEBUG if ENV.key?('DEBUG')
set :server_settings, :timeout => 300

set :host_authorization => { permitted_hosts: [] }

if ENV.key?('ECS_CONTAINER_METADATA_URI')
  Sinatra::Application.logger.formatter = proc do |severity, _datetime, _progname, msg|
    json = {
      # time: datetime.strftime('%Y-%m-%dT%H:%M:%S.%L%z'),
      'log.level': severity,
      message: msg
    }.to_json
    "#{json}\n"
  end
end

run Sinatra::Application
