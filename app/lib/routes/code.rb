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
        srccode = UC3Code::SourceCodeClient.client

        adminui_show_table(
          AdminUI::Context.new(request.path),
          srccode.repo_tags(repo)
        )
      end

      app.get '/source/artifacts/*' do |repo|
        srccode = UC3Code::SourceCodeClient.client

        adminui_show_table(
          AdminUI::Context.new(request.path),
          srccode.artifacts_table(repo)
        )
      end

      app.get '/source/images/*' do |repo|
        srccode = UC3Code::SourceCodeClient.client

        adminui_show_table(
          AdminUI::Context.new(request.path),
          srccode.images_table(repo)
        )
      end

      app.get '/source/artifact/*/*/*' do |artifact, version, asset|
        srccode = UC3Code::SourceCodeClient.client
        content_type :xml
        srccode.artifact(artifact, version, asset)
      end

      app.get '/source/artifact_manifest/*/*/*' do |artifact, version, asset|
        srccode = UC3Code::SourceCodeClient.client
        srccode.artifact_manifest(artifact, version, asset).to_json

        adminui_show_table(
          AdminUI::Context.new(request.path),
          srccode.artifact_manifest_table(srccode.artifact_manifest(artifact, version, asset))
        )
      end

      app.get '/source/artifact_command/*/*/*' do |artifact, version, asset|
        data = <<~EOF_CMD
          aws codeartifact get-package-version-asset \\
            --domain=cdlib-uc3-mrt --repository=uc3-mrt-java \\
            --package=#{artifact} --package-version=#{version} \\
            --format=maven --namespace=org.cdlib.mrt \\
            --asset=#{asset} \\
            #{artifact}.war
        EOF_CMD
        erb :pre,
          :layout => :page_layout,
          :locals => {
            context: AdminUI::Context.new(request.path),
            data: data
          }
      end

      app.get '/source' do
        adminui_show_markdown(
          AdminUI::Context.new(request.path),
          'app/markdown/mrt/source.md'
        )
      end

      app.get '/source/conventions' do
        adminui_show_markdown(
          AdminUI::Context.new(request.path),
          'app/markdown/mrt/source.md'
        )
      end

      app.get '/source/conventions/*' do |md|
        adminui_show_markdown(
          AdminUI::Context.new(request.path),
          "app/markdown/mrt/conventions/#{md}"
        )
      end

      app.post '/source/artifacts/delete/*' do |tag|
        srccode = UC3Code::SourceCodeClient.client
        arr = []
        request.body.each_line do |line|
          srccode.delete_artifact(tag, line.strip)
          arr << line.strip
        end
        { message: "Deleted: #{arr.join(', ')} for tag #{tag}" }.to_json
      rescue StandardError => e
        content_type :json
        { message: "ERROR: #{e.class}: #{e.message}" }.to_json
      end

      app.post '/source/images/delete/*' do |tag|
        srccode = UC3Code::SourceCodeClient.client
        arr = []
        request.body.each_line do |line|
          srccode.delete_image(tag, line.strip)
          arr << line.strip
        end
        { message: "Deleted: #{arr.join(', ')} for tag #{tag}" }.to_json
      rescue StandardError => e
        content_type :json
        { message: "ERROR: #{e.class}: #{e.message}" }.to_json
      end

      app.post '/source/images/retag/*/*' do |tag, newtag|
        srccode = UC3Code::SourceCodeClient.client
        arr = []
        request.body.each_line do |line|
          srccode.retag_image(tag, newtag, line.strip)
          arr << line.strip
        end
        { message: "Retagged: #{arr.join(', ')} for tag #{tag} --> #{newtag}" }.to_json
      rescue StandardError => e
        content_type :json
        { message: "ERROR: #{e.class}: #{e.message}" }.to_json
      end

      app.post '/source/images/untag/*' do |tag|
        srccode = UC3Code::SourceCodeClient.client
        arr = []
        request.body.each_line do |line|
          srccode.untag_image(tag, line.strip)
          arr << line.strip
        end
        { message: "Untag: #{arr.join(', ')} for tag #{tag}" }.to_json
      rescue StandardError => e
        content_type :json
        { message: "ERROR: #{e.class}: #{e.message}" }.to_json
      end
    end
  end
  register UC3CodeRoutes
end
