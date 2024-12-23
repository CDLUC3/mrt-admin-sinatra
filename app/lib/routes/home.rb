# frozen_string_literal: true

require 'sinatra/base'
require_relative '../ui/context'

# custom sinatra routes
module Sinatra
  # client specific routes
  module UC3HomeRoutes
    def self.registered(app)
      AdminUI::Context.topmenu.create_menu_for_path('/test/aaa', 'AAA')
      AdminUI::Context.topmenu.create_menu_item_for_path('/test/aaa', '/test?aaa', 'Test AAA')
      AdminUI::Context.topmenu.create_menu_item_for_path('/test/aaa', '/test?bbb', 'Test BBB')
      AdminUI::Context.topmenu.create_menu_item_for_path('/test/aaa', '/test?ccc', 'Test DDD')
      (1..40).each do |i|
        AdminUI::Context.topmenu.create_menu_item_for_path('/test', "/test?ccc#{i}", "Test DDD #{i}")
      end
    end
  end
  register UC3HomeRoutes
end
