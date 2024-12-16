# frozen_string_literal: true

require 'sinatra'
require 'sinatra/base'
require_relative 'lib/routes/code.rb'

set :bind, '0.0.0.0'

# modularize route handling by specific clients
include Sinatra::UC3CodeRoutes
