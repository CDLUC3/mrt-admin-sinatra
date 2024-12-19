# frozen_string_literal: true

require 'json'
require 'rack'
require 'base64'

# Global object that responds to the call method. Stay outside of the handler
# to take advantage of container reuse
# $app ||= Rack::Builder.parse_file("#{__dir__}/app/config.ru").first
$app ||= Rack::Builder.parse_file("#{__dir__}/app/config.ru")

ENV['RACK_ENV'] ||= 'production'

module LambdaFunctions
  # Lambda entry point for the Admin Tool
  class Handler
    def self.process(event:, context:)
      puts event
      puts context
      unless context.nil?
        ENV['LAMBDA_CONTEXT_FUNCTION_NAME']=context.function_name
        ENV['LAMBDA_CONTEXT_FUNCTION_VERSION']=context.function_version
        ENV['LAMBDA_CONTEXT_FUNCTION_ARN']=context.invoked_function_arn
        ENV['LAMBDA_CONTEXT_MEMORY_LIMIT_IN_MB']=context.memory_limit_in_mb.to_s
        ENV['LAMBDA_CONTEXT_TIMEOUT_MS']=context.get_remaining_time_in_millis.to_s
      end
    
      # Check if the body is base64 encoded. If it is, try to decode it
      body =
        if event['isBase64Encoded']
          Base64.decode64 event['body']
        else
          event['body']
        end || ''
    
      # Rack expects the querystring in plain text, not a hash
      headers = event.fetch 'headers', {}
    
      # Environment required by Rack (http://www.rubydoc.info/github/rack/rack/file/SPEC)
      env = {
        'REQUEST_METHOD' => event.fetch('httpMethod', 'GET'),
        'SCRIPT_NAME' => '',
        'PATH_INFO' => event.fetch('path', ''),
        'QUERY_STRING' => (event['queryStringParameters'] || {}).map { |k, v| "#{k}=#{v}" }.join('&'),
        'SERVER_NAME' => headers.fetch('Host', 'localhost'),
        'SERVER_PORT' => headers.fetch('X-Forwarded-Port', 443).to_s,
    
        # 'rack.version' => Rack::VERSION,
        'rack.url_scheme' => headers.fetch('CloudFront-Forwarded-Proto') { headers.fetch('X-Forwarded-Proto', 'https') },
        'rack.input' => StringIO.new(body),
        'rack.errors' => $stderr
      }
    
      # Pass request headers to Rack if they are available
      headers.each_pair do |key, value|
        # Content-Type and Content-Length are handled specially per the Rack SPEC linked above.
        name = key.upcase.gsub '-', '_'
        header =
          case name
          when 'CONTENT_TYPE', 'CONTENT_LENGTH'
            name
          else
            "HTTP_#{name}"
          end
        env[header] = value.to_s
      end
    
      begin
        # Response from Rack must have status, headers and body
        status, headers, body = $app.call env
    
        # body is an array. We combine all the items to a single string
        body_content = ''
        body.each do |item|
          body_content += item.to_s
        end
    
        is_base64_encoded = headers.fetch('content-type', '').start_with?('image/')
    
        # We return the structure required by AWS API Gateway since we integrate with it
        # https://docs.aws.amazon.com/apigateway/latest/developerguide/set-up-lambda-proxy-integrations.html
        response = {
          statusCode: status,
          headers: headers,
          body: is_base64_encoded ? Base64.strict_encode64(body_content) : body_content,
          is_base64_encoded: is_base64_encoded
        }
      rescue StandardError => e
        # If there is _any_ exception, we return a 500 error with an error message
    
        response = {
          'statusCode' => 500,
          'body' => e.message
        }
      end
    
      # By default, the response serializer will call #to_json for us
      response
    end
  end
end