# frozen_string_literal: true

require 'sinatra/base'
require_relative '../client/code/source_code'
require_relative '../ui/context'

# custom sinatra routes
module Sinatra
  # client specific routes
  module UC3CodeRoutes
    def self.registered(app)
      srccode = UC3Code::SourceCodeClient.new

      app.get '/source' do
        status 200

        erb :source,
          :layout => :page_layout,
          :locals => {
            context: AdminUI::Context.new('Merritt Admin Tool - UC3 Account'),
            repos: srccode.repos.keys
          }
      end

      app.get '/git/*' do |repo|
        erb :table,
          :layout => :page_layout,
          :locals => {
            context: AdminUI::Context.new(
              "Repo Tags: #{srccode.reponame(repo)}",
              breadcrumbs: [
                { title: 'Source', url: '/source' }
              ]
            ),
            table: srccode.repo_tags(repo)
          }
      end
    end
  end
  register UC3CodeRoutes
end
