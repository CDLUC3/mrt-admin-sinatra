# frozen_string_literal: true

require 'sinatra/base'
require_relative '../client/code/source_code'
require_relative '../ui/context'

# custom sinatra routes
module Sinatra
  # client specific routes
  module UC3CodeRoutes
    def self.registered(app)
      AdminUI::TopMenu.instance.create_menu_item_for_path(
        AdminUI::MENU_SOURCE,
        AdminUI::MENU_SOURCE,
        'Source Code Repos'
      )
      app.get '/source' do
        erb :source,
          :layout => :page_layout,
          :locals => {
            context: AdminUI::Context.new(request.path),
            repos: UC3Code::SourceCodeClient.new.repos.keys
          }
      end

      app.get '/source/*' do |repo|
        srccode = UC3Code::SourceCodeClient.new

        erb :table,
          :layout => :page_layout,
          :locals => {
            context: AdminUI::Context.new(request.path, title: "Repo Tags: #{srccode.reponame(repo)}"),
            table: srccode.repo_tags(repo)
          }
      end
    end
  end
  register UC3CodeRoutes
end
