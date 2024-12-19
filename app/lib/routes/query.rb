# frozen_string_literal: true

require 'sinatra/base'
require_relative '../client/query/query'
require_relative '../ui/context'

# custom sinatra routes
module Sinatra
  # client specific routes
  module UC3QueryRoutes
    def self.registered(app)

      AdminUI::Context.add_menu_item(AdminUI::MENU_QUERY, 'Query')
    end
  end
  register UC3ResourcesRoutes
end
