require 'aws-sdk-codeartifact'

class CodeArtifact
  def initialize(repohash)
    @client = Aws::CodeArtifact::Client.new(region: 'us-west-2')
    @artifacts = repohash.fetch(:artifacts, [])
  end

  def list_package_versions
    res = {}
    @artifacts.each do |artifact|
      pv = @client.list_package_versions(
        domain: 'cdlib-uc3-mrt',
        repository: 'uc3-mrt-java',
        package: artifact,
        format: 'maven',
        namespace: 'org.cdlib.mrt'
      )
      pv.versions.each do |v|
        res[v.version] = res.fetch(v.version, [])
        res[v.version] << artifact
      end
    end
    res
  end
end
