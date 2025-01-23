require 'zk'
require 'merritt_zk'
require 'yaml'
require_relative '../uc3_client'
require_relative '../../ui/context'

# Scope custom code for UC3 to distinguish from 3rd party classes
module UC3Queue
  # Query for ZK nodes
  # VPC peering does not allow this, so this connection will not work until ZK is running in the UC3
  class ZKClient < UC3::UC3Client
    def self.client
      UC3::UC3Client.clients.fetch(self.class.to_s, ZKClient.new)
    end

    def initialize
      puts MerrittZK::JobState::Estimating
      map = UC3::UC3Client.lookup_map('app/config/mrt/zk.yml')
      @zk = ZK.new(map.fetch('zkconn', ''), timeout: 1)
      @zk.exists?('/')
      super(enabled: true)
    rescue StandardError => e
      super(enabled: false, message: e.to_s)
    end
  end
end
