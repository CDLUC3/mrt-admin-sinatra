# frozen_string_literal: true

require 'sinatra/base'
require_relative '../ui/context'
require_relative '../client/uc3_client'

# custom sinatra routes
module Sinatra
  # client specific routes
  module UC3HomeRoutes
    def self.add_menu_item(paths, item)
      if !item.fetch(:admindeploy, '').empty? && ENV.fetch('ADMINDEPLOY', 'lambda') != item.fetch(:admindeploy, '')
        return
      end

      np = paths.clone
      leaf = item.fetch(:path, '')
      title = item.fetch(:title, '')
      route = item.fetch(:route, '')
      np.append(leaf) unless leaf.empty?
      items = item.fetch(:items, [])
      AdminUI::TopMenu.instance.create_menu_item_for_path(
        np.join('/'),
        route,
        title,
        description: item.fetch(:description, ''),
        tbd: item.fetch(:tbd, false),
        external: item.fetch(:external, false),
        method: item.fetch(:method, 'get'),
        breadcrumb: item.fetch(:breadcrumb, false),
        menu: route.empty? || !items.empty?
      )
      items.each do |citem|
        add_menu_item(np, citem)
      end
    end

    def self.load_menu_file(menu_file)
      UC3::UC3Client.load_config(menu_file).fetch(:items, {}).each do |menu|
        add_menu_item([''], menu)
      end
    end

    def self.registered(_app) end
  end
  register UC3HomeRoutes
end
