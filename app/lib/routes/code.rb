# frozen_string_literal: true

require 'sinatra/base'
require_relative '../client/code/source_code'
require_relative '../ui/context'

# custom sinatra routes
module Sinatra
  # client specific routes
  module UC3CodeRoutes
    def self.registered(app)
      app.get '/source/tags/*' do |repo|
        srccode = UC3Code::SourceCodeClient.new

        erb :table,
          :layout => :page_layout,
          :locals => {
            context: AdminUI::Context.new(request.path),
            table: srccode.repo_tags(repo)
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

      app.get '/source/images/*' do |repo|
        srccode = UC3Code::SourceCodeClient.new

        erb :table,
          :layout => :page_layout,
          :locals => {
            context: AdminUI::Context.new(request.path),
            table: srccode.images_table(repo)
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

      app.get '/source' do
        erb :markdown,
          :layout => :page_layout,
          :locals => {
            md_file: 'app/markdown/mrt/source.md',
            context: AdminUI::Context.new(request.path)
          }
      end

      app.get '/source/conventions' do
        erb :markdown,
          :layout => :page_layout,
          :locals => {
            md_file: "app/markdown/mrt/source.md",
            context: AdminUI::Context.new(request.path)
          }
      end

      app.get '/source/conventions/*' do |md|
        erb :markdown,
          :layout => :page_layout,
          :locals => {
            md_file: "app/markdown/mrt/conventions/#{md}",
            context: AdminUI::Context.new(request.path)
          }
      end

      app.post '/source/artifacts/delete/*' do |tag|
        begin
          srccode = UC3Code::SourceCodeClient.new
          arr = []
          request.body.each_line do |line|
            srccode.delete_artifact(tag, line.strip)
            arr << line.strip
          end
          {message: "Deleted: #{arr.join(', ')} for tag #{tag}"}.to_json
        rescue StandardError => e
          content_type :json
          {message: "ERROR: #{e.class}: #{e.message}"}.to_json
        end
      end

      app.post '/source/images/delete/*' do |tag|
        begin
          srccode = UC3Code::SourceCodeClient.new
          arr = []
          request.body.each_line do |line|
            srccode.delete_image(tag, line.strip)
            arr << line.strip
          end
          {message: "Deleted: #{arr.join(', ')} for tag #{tag}"}.to_json
        rescue StandardError => e
          content_type :json
          {message: "ERROR: #{e.class}: #{e.message}"}.to_json
        end
      end
    end
  end
  register UC3CodeRoutes
end
