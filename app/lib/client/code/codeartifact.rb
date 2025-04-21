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
            namespace: ARTNAMESPACE
          )
        rescue StandardError => e
          puts "Client ERR: #{e}: #{@client}"
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
            namespace: ARTNAMESPACE
          )
        rescue StandardError => e
          puts "Client ERR: #{e}: #{@client}"
          return res
        end
        pv.versions.each do |v|
          rec = { 
            version: v.version,
            package: artifact,
            domain: ARTDOMAIN,
            repository: ARTREPOSITORY,
            format: ARTFORMAT,
            namespace: ARTNAMESPACE,
            assets: [],
            pom: nil
          }
          @client.list_package_version_assets({
            domain: ARTDOMAIN,
            repository: ARTREPOSITORY,
            format: ARTFORMAT,
            namespace: ARTNAMESPACE,
            package: artifact,
            package_version: v.version
          }).assets.each do |asset|
            if asset.name.downcase.end_with?('.pom')
              rec[:pom] = {
                value: asset.name,
                href: "/source/artifact/#{artifact}/#{v.version}/#{asset.name}"
              }
            elsif asset.name.downcase.end_with?('.war')
              rec[:assets] << {
                value: asset.name,
                href: "/source/artifact_manifest/#{artifact}/#{v.version}/#{asset.name}"
              }
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
      res = @client.get_package_version_asset(
        domain: ARTDOMAIN,
        repository: ARTREPOSITORY,
        format: ARTFORMAT,
        namespace: ARTNAMESPACE,
        package: artifact,
        package_version: version,
        asset: asset
      )
      return '' if res.nil?
      return res.asset
    end

    def artifact_table(arr)
      table = AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:package, header: 'Package'),
          AdminUI::Column.new(:version, header: 'Version'),
          AdminUI::Column.new(:pom, header: 'POM'),
          AdminUI::Column.new(:assets, header: 'Assets')
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
      return res
    end

    def artifact_manifest_table(res)
      table = AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:dir, header: 'Dir', filterable: true),
          AdminUI::Column.new(:name, header: 'Name'),
          AdminUI::Column.new(:ext, header: 'Ext', filterable: true),
          AdminUI::Column.new(:mrt, header: 'Merritt', filterable: true),
          AdminUI::Column.new(:size, header: 'Size'),
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
  end
end
