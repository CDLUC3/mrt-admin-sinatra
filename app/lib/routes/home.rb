# frozen_string_literal: true

require 'sinatra/base'
require_relative '../ui/context'
require_relative '../client/uc3_client'

# custom sinatra routes
module Sinatra
  # client specific routes
  module UC3HomeRoutes
    def self.add_menu_item(paths, item)
      np = paths.clone
      leaf = item.fetch(:path, '')
      title = item.fetch(:title, '')
      route = item.fetch(:route, '')
      np.append(leaf) unless leaf.empty?
      AdminUI::TopMenu.instance.create_menu_item_for_path(
        np.join('/'),
        route,
        title,
        description: item.fetch(:description, ''),
        tbd: item.fetch(:tbd, false),
        breadcrumb: item.fetch(:breadcrumb, false)
      )
      item.fetch(:items, []).each do |citem|
        add_menu_item(np, citem)
      end
    end

    def self.load_menu_file
      UC3::UC3Client.load_config('app/config/menu.yml').fetch(:items, {}).each do |menu|
        add_menu_item([''], menu)
      end
    end

    def self.registered(app)
      load_menu_file
    end
  end
  register UC3HomeRoutes
end
