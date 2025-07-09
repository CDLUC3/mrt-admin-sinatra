# frozen_string_literal: true

require 'sinatra/base'
require 'sinatra/contrib'
require_relative '../ui/context'
require_relative '../client/uc3_client'

# custom sinatra routes
module Sinatra
  # client specific routes
  module UC3HomeRoutes
    def self.add_menu_item(paths, item)
      return if !item.fetch(:admindeploy,
        '').empty? && ENV.fetch('ADMINDEPLOY', 'lambda') != item.fetch(:admindeploy, '')

      np = paths.clone
      leaf = item.fetch(:path, '')
      title = item.fetch(:title, '')
      route = item.fetch(:route, '')
      confmsg = item.fetch(:confmsg, title)
      np.append(leaf) unless leaf.empty?
      items = item.fetch(:items, [])
      AdminUI::TopMenu.instance.create_menu_item_for_path(
        np.join('/'),
        route,
        title,
        description: item.fetch(:description, ''),
        confmsg: confmsg,
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

    def self.registered(app)
      app.get '/test/routes' do
        content_type :json
        UC3::TestClient.client.test_paths.to_json
      end

      app.get '/test/routes/count' do
        content_type :text
        UC3::TestClient.client.test_paths.length.to_s
      end

      app.get '/test/consistency' do
        content_type :json
        UC3::TestClient.client.consistency_checks.to_json
      end

      app.get '/test/consistency/run' do
        arr = UC3::TestClient.client.consistency_checks
        arr.each do |route|
          sep = route.include?('?') ? '&' : '?'
          uri = URI.parse("http://localhost:9292/#{route}#{sep}format=json")
          Net::HTTP.get_response(uri)
        end
        redirect '/queries/consistency/daily'
      end

      app.get '/test/consistency/count' do
        content_type :text
        UC3::TestClient.client.consistency_checks.length.to_s
      end

      app.get '/robots.txt' do
        content_type :text
        "User-agent: *\nDisallow: /"
      end
    end
  end
  register UC3HomeRoutes
end
