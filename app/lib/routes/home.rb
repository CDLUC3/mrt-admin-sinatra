# frozen_string_literal: true

require 'sinatra/base'
require 'sinatra/contrib'
require_relative '../ui/context'
require_relative '../client/uc3_client'

# custom sinatra routes
module Sinatra
  # client specific routes
  module UC3HomeRoutes
    def self.add_menu_item(paths, item, classes: '')
      np = paths.clone
      leaf = item.fetch(:path, '')
      title = item.fetch(:title, '')
      route = item.fetch(:route, '')
      confmsg = item.fetch(:confmsg, title)
      np.append(leaf) unless leaf.empty?
      items = item.fetch(:items, [])
      classes = item.fetch(:classes, classes)
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
        menu: route.empty? || !items.empty?,
        classes: classes
      )
      items.each do |citem|
        next if citem.fetch(:disable, '').split(/, */).include?(ENV.fetch('configkey', 'default'))

        add_menu_item(np, citem, classes: classes)
      end
    end

    def self.load_menu_file(menu_file)
      UC3::UC3Client.load_config(menu_file).fetch(:items, {}).each do |menu|
        next if menu.fetch(:disable, '').split(/, */).include?(ENV.fetch('configkey', 'default'))

        add_menu_item([''], menu, classes: menu.fetch(:classes, ''))
      end
    end

    def self.registered(app)
      app.get '/test/routes' do
        content_type :json
        UC3::TestClient.client.test_paths.to_json
      end

      app.get '/test/routes/links' do
        table = AdminUI::FilterTable.new(
          columns: [
            AdminUI::Column.new(:link, header: 'Link')
          ]
        )
        UC3::TestClient.client.test_paths.each do |route|
          table.add_row(AdminUI::Row.make_row(table.columns, {
            link: { value: route, href: route }
          }))
        end

        adminui_show_table(
          AdminUI::Context.new(request.path),
          table
        )
      end

      app.get '/test/consistency' do
        content_type :json
        UC3::TestClient.client.consistency_checks.to_json
      end

      app.get '/test/consistency/links' do
        table = AdminUI::FilterTable.new(
          columns: [
            AdminUI::Column.new(:link, header: 'Link')
          ]
        )
        UC3::TestClient.client.consistency_checks.each do |route|
          table.add_row(AdminUI::Row.make_row(table.columns, {
            link: { value: route, href: route }
          }))
        end

        adminui_show_table(
          AdminUI::Context.new(request.path),
          table
        )
      end

      app.get '/robots.txt' do
        content_type :text
        "User-agent: *\nDisallow: /"
      end

      app.get '/ops/cloudwatch' do
        redirect ENV.fetch('CLOUDWATCH_URL', '/')
      end

      app.get '/ops/opensearch' do
        redirect ENV.fetch('OPENSEARCH_URL', '/')
      end

      app.get '/markdown/*' do |md|
        adminui_show_markdown(
          AdminUI::Context.new(request.path),
          "app/markdown/mrt/#{md}"
        )
      end

      app.get '/index.html' do
        redirect '/'
      end
    end
  end
  register UC3HomeRoutes
end
