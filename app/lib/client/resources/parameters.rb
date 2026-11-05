# frozen_string_literal: true

require 'aws-sdk-ssm' unless ENV.fetch('MERRITT_ECS', '').empty?
require_relative '../uc3_client'

# Scope custom code for UC3 to distinguish from 3rd party classes
module UC3Resources
  # Query for repository images by tag
  class ParametersClient < UC3::UC3Client
    def self.client
      UC3::UC3Client.clients.fetch(self.class.to_s, ParametersClient.new)
    end

    def initialize
      @client = Aws::SSM::Client.new(
        region: UC3::UC3Client.region
      )
      # @client.get_parameters_by_path(path: '/uc3/foo/bar')
      super(enabled: enabled)
    rescue StandardError => e
      super(enabled: false, message: e.to_s)
    end

    def enabled
      !@client.nil?
    end

    def list_parameters
      table = AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:path, header: 'Path'),
          AdminUI::Column.new(:type, header: 'Type', filterable: true),
          AdminUI::Column.new(:key_id, header: 'Key', filterable: true),
          AdminUI::Column.new(:value, header: 'Value'),
          AdminUI::Column.new(:modified, header: 'Modified'),
          AdminUI::Column.new(:version, header: 'Version'),
          AdminUI::Column.new(:status, header: 'Status', filterable: true)
        ],
        description: %(
This table displays the Merritt parameters for the stack found in the SSM Parameter Store.

SecureString values will not be displayed.  Their KMS key name will be displayed.

There is a fair amout of logic that filters our parameters

- from other UC3 services
- from other Merritt Stacks

If a SecureString is found

- WARN if it older than 90 days
- FAIL if it older than 1 year
- SKIP if it is a SecureString for an SSH public key or for Integration Tests

To obtain the full history for a parameter named PARAMETER_NAME, run the following command:

```
aws ssm get-parameter-history --name PARAMETER_NAME
```

```
aws ssm get-parameter-history --name PARAMETER_NAME --with-decryption
```
)
      )
      return table unless enabled

      params = {}

      next_token = 'na'
      opt = { path: ENV.fetch('SSM_ROOT_PATH', '/uc3'), recursive: true }
      while next_token
        res = @client.get_parameters_by_path(opt)
        res.parameters.each do |param|
          path = param.name

          next if path =~ %r{^/uc3/(dmp|dmsp|rams|sceptre|ops)/}
          if path =~ %r{^/uc3/(AccountId|CidrBlock|CodeStarConnectionArn|HostedZoneId|MainAccountId|MainAccountBackupVault)$}
            next
          end
          next if path =~ %r{/(BackupVaultArn|CfnServiceRoleArn)$}

          if (path =~ %r{^/uc3/mrt/(prd|stg|dev)/}) && !path.start_with?("/uc3/mrt/#{UC3::UC3Client.stack_name_brief}/")
            next
          end

          value = param.type == 'SecureString' ? '***' : param.value
          value = { value: "#{value[0..100]}...", title: value } if value.length > 100

          status = if param.type == 'SecureString'
                     if path =~ %r{(/uc3/ssh/|/integ-tests/)}
                       'SKIP'
                     elsif Time.now - param.last_modified_date > 60 * 60 * 24 * 365
                       'FAIL'
                     elsif Time.now - param.last_modified_date > 60 * 60 * 24 * 90
                       'WARN'
                     else
                       'PASS'
                     end
                   else
                     'PASS'
                   end

          params[path] = {
            path: path,
            type: param.type,
            value: value,
            modified: date_format(param.last_modified_date, convert_timezone: true),
            version: param.version,
            status: status
          }
        end
        next_token = res.next_token
        opt[:next_token] = next_token
      end
      next_token = 'na'
      opt = { filters: [{ key: 'Type', values: ['SecureString'] }] }
      while next_token
        res = @client.describe_parameters(opt)
        res.parameters.each do |param|
          path = param.name
          next unless params.key?(path)

          params[path][:key_id] = param.key_id
        end
        next_token = res.next_token
        opt[:next_token] = next_token
      end
      params.sort.each do |_key, value|
        table.add_row(AdminUI::Row.make_row(table.columns, value))
      end
      table
    end
  end
end
