# frozen_string_literal: true

require 'sinatra/base'
require_relative '../client/code/source_code'
require_relative '../ui/context'

# custom sinatra routes
module Sinatra
  # client specific routes
  module UC3CodeRoutes
    def self.registered(app)
      app.get '/source' do
        erb :table,
        :layout => :page_layout,
        :locals => {
            context: AdminUI::Context.new(request.path),
            table: UC3Code::SourceCodeClient.new.repos
          }
      end

      app.get '/source/artifacts/*' do |repo|
        content_type :json
        srccode = UC3Code::SourceCodeClient.new
        srccode.artifacts(repo).to_json
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
