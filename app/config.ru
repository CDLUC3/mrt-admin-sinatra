# frozen_string_literal: true

require 'rack'
require 'rack/contrib'
require_relative 'admin'

set :root, File.dirname(__FILE__)
set :views, proc { File.join(root, 'views') }

puts "ARGV: #{ARGV}"

run Sinatra::Application
