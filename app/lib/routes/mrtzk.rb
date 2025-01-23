# frozen_string_literal: true

require 'sinatra/base'
require 'uri'
require_relative '../client/zk/mrtzk'
require_relative '../ui/context'

# custom sinatra routes
module Sinatra
  # client specific routes
  module UC3ZKRoutes
    def self.registered(app)
      # tbd
    end
  end
  register UC3ZKRoutes
end
