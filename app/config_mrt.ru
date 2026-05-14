# frozen_string_literal: true

require 'rack'
require 'rack/contrib'
require 'logger'
require_relative 'admin_mrt'

set :root, File.dirname(__FILE__)
set :views, proc { File.join(root, 'views') }
set :logger, Logger.new($stdout, level: Logger::INFO)

set :host_authorization => { permitted_hosts: [] }

run Sinatra::Application

if ENV.key?('ECS_CONTAINER_METADATA_URI')
  Sinatra::Application.logger.formatter = proc do |severity, datetime, _progname, msg|
    json = {
      # time: datetime.strftime('%Y-%m-%dT%H:%M:%S.%L%z'),
      "log.level": severity,
      "message": msg
    }.to_json
    "#{json}\n"
  end
end
