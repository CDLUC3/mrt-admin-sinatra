# frozen_string_literal: true

require 'aws-sdk-codeartifact'
require_relative '../uc3_client'
require 'zip'

# Scope custom code for UC3 to distinguish from 3rd party classes
module UC3Code
  # Query for repository artifacts by code
  class CodeArtifactClient < UC3::UC3Client
    ARTDOMAIN = 'cdlib-uc3-mrt'
    ARTREPOSITORY = 'uc3-mrt-java'
    ARTFORMAT = 'maven'
    ARTNAMESPACE = 'org.cdlib.mrt'

    def initialize
      @client = Aws::CodeArtifact::Client.new(region: UC3::UC3Client.region)
      @client.describe_domain(domain: ARTDOMAIN)
      super(enabled: enabled)
    rescue StandardError => e
      super(enabled: false, message: e.to_s)
    end

    def enabled
      !@client.nil?
    end

    def list_package_versions(repohash: {})
      res = {}
      return res unless enabled

      repohash.fetch(:artifacts, []).each do |artifact|
        begin
          pv = @client.list_package_versions(
            domain: ARTDOMAIN,
            repository: ARTREPOSITORY,
            package: artifact,
            format: ARTFORMAT,
            namespace: repohash.fetch(:namespace, ARTNAMESPACE)
          )
        rescue StandardError
          # puts "Client ERR: #{e}: #{@client}"
          return res
        end
        pv.versions.each do |v|
          res[v.version] = res.fetch(v.version, [])
          res[v.version] << artifact
        end
      end
      res
    end

    def list_package_artifacts(repohash: {})
      res = []
      return res unless enabled

      repohash.fetch(:artifacts, []).each do |artifact|
        begin
          pv = @client.list_package_versions(
            domain: ARTDOMAIN,
            repository: ARTREPOSITORY,
            package: artifact,
            format: ARTFORMAT,
            namespace: repohash.fetch(:namespace, ARTNAMESPACE)
          )
        rescue StandardError
          # puts "Client ERR: #{e}: #{@client}"
          return res
        end
        pv.versions.each do |v|
          rec = {
            status: v.status,
            version: v.version,
            semantic: UC3::UC3Client.semantic_prefix_tag?(v.version),
            package: artifact,
            domain: ARTDOMAIN,
            repository: ARTREPOSITORY,
            format: ARTFORMAT,
            namespace: repohash.fetch(:namespace, ARTNAMESPACE),
            assets: [],
            pom: nil,
            command: ''
          }
          rec[:published] = @client.describe_package_version(
            domain: ARTDOMAIN,
            repository: ARTREPOSITORY,
            format: ARTFORMAT,
            namespace: repohash.fetch(:namespace, ARTNAMESPACE),
            package: artifact,
            package_version: v.version
          ).package_version.published_time
          @client.list_package_version_assets({
            domain: ARTDOMAIN,
            repository: ARTREPOSITORY,
            format: ARTFORMAT,
            namespace: repohash.fetch(:namespace, ARTNAMESPACE),
            package: artifact,
            package_version: v.version
          }).assets.each do |asset|
            if asset.name.downcase.end_with?('.pom')
              rec[:pom] = {
                value: asset.name,
                href: "/source/artifact/#{artifact}/#{v.version}/#{asset.name}"
              }
            elsif asset.name.downcase.end_with?('.war') || asset.name.downcase.end_with?('.jar')
              rec[:assets] << {
                value: asset.name,
                href: "/source/artifact_manifest/#{artifact}/#{v.version}/#{asset.name}"
              }
              rec[:command] = [
                {
                  value: 'download cmd',
                  href: "/source/artifact_command/#{artifact}/#{v.version}/#{asset.name}",
                  cssclass: 'button'
                }
              ]
              unless UC3::UC3Client.keep_artifact_version?(v.version)
                rec[:command] << {
                  value: 'Delete',
                  href: "/source/artifacts/delete/#{v.version}",
                  cssclass: 'button',
                  post: true,
                  disabled: false,
                  data: artifact
                }
              end
            else
              rec[:assets] << asset.name
            end
          end
          res << rec
        end
      end
      res
    end

    def artifact(artifact, version, asset)
      namespace = artifact == 'MerrittZK' ? 'org.cdlib.mrt.zk' : ARTNAMESPACE
      res = @client.get_package_version_asset(
        domain: ARTDOMAIN,
        repository: ARTREPOSITORY,
        format: ARTFORMAT,
        namespace: namespace,
        package: artifact,
        package_version: version,
        asset: asset
      )
      return '' if res.nil?

      res.asset
    end

    def artifact_table(arr)
      table = AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:published, header: 'Published'),
          AdminUI::Column.new(:package, header: 'Package'),
          AdminUI::Column.new(:version, header: 'Version'),
          AdminUI::Column.new(:semantic, header: 'Semantic'),
          AdminUI::Column.new(:pom, header: 'POM'),
          AdminUI::Column.new(:assets, header: 'Assets'),
          AdminUI::Column.new(:command, header: 'Command')
        ]
      )
      arr.each do |row|
        table.add_row(
          AdminUI::Row.make_row(
            table.columns,
            row
          )
        )
      end
      table
    end

    def artifact_manifest(artifact, version, asset)
      res = {}
      Zip::File.open_buffer(artifact(artifact, version, asset)) do |z|
        z.each do |entry|
          next if entry.name.end_with?('/')

          res[entry.name] = {
            dir: File.dirname(entry.name),
            name: File.basename(entry.name),
            size: entry.size,
            ext: File.basename(entry.name).split('.').last,
            mrt: File.basename(entry.name).start_with?('mrt-')
          }
        end
      end
      res
    end

    def artifact_manifest_table(res)
      table = AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:dir, header: 'Dir', filterable: true),
          AdminUI::Column.new(:name, header: 'Name'),
          AdminUI::Column.new(:ext, header: 'Ext', filterable: true),
          AdminUI::Column.new(:mrt, header: 'Merritt', filterable: true),
          AdminUI::Column.new(:size, header: 'Size')
        ]
      )
      res.keys.sort.each do |path|
        table.add_row(
          AdminUI::Row.make_row(
            table.columns,
            res[path]
          )
        )
      end
      table
    end

    def delete_artifact(tag, artifact)
      namespace = artifact == 'MerrittZK' ? 'org.cdlib.mrt.zk' : ARTNAMESPACE
      @client.delete_package_versions(
        domain: ARTDOMAIN,
        repository: ARTREPOSITORY,
        format: ARTFORMAT,
        namespace: namespace,
        package: artifact,
        versions: [tag]
      )
    end
  end
end
