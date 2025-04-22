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
        srccode = UC3Code::SourceCodeClient.new

        erb :table,
          :layout => :page_layout,
          :locals => {
            context: AdminUI::Context.new(request.path),
            table: srccode.artifacts_table(repo)
          }
      end

      app.get '/source/artifact/*/*/*' do |artifact, version, asset|
        srccode = UC3Code::SourceCodeClient.new
        content_type :xml
        srccode.artifact(artifact, version, asset)
      end

      app.get '/source/artifact_manifest/*/*/*' do |artifact, version, asset|
        srccode = UC3Code::SourceCodeClient.new
        srccode.artifact_manifest(artifact, version, asset).to_json
        erb :table,
          :layout => :page_layout,
          :locals => {
            context: AdminUI::Context.new(request.path),
            table: srccode.artifact_manifest_table(srccode.artifact_manifest(artifact, version, asset))
          }
      end

      app.get '/source/artifact_command/*/*/*' do |artifact, version, asset|
        data = <<~EOF
        aws codeartifact get-package-version-asset \\
          --domain=cdlib-uc3-mrt --repository=uc3-mrt-java \\
          --package=#{artifact} --package-version=#{version} \\
          --format=maven --namespace=org.cdlib.mrt \\
          --asset=#{asset} \\
          #{artifact}.war
        EOF
        erb :pre,
          :layout => :page_layout,
          :locals => {
            context: AdminUI::Context.new(request.path),
            data: data
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
