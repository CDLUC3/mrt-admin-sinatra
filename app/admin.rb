# frozen_string_literal: true

require 'sinatra'
require 'sinatra/base'
require_relative 'lib/routes/code'

set :bind, '0.0.0.0'

include Sinatra::UC3CodeRoutes

get '/context' do
  erb :table,
    :layout => :page_layout,
    :locals => {
      context: AdminUI::Context.new("Admin Tool Context"),
      table: UC3::UC3Client.new.context
    }
end