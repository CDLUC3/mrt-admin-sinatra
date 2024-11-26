require 'sinatra'
require 'sinatra/base'

set :bind, '0.0.0.0'

get "/" do
  status 200

  erb :index
end

get "/foo" do
  status 200
  'Hello foo!'
end

get "/favicon.ico" do
  content_type 'image/x-icon'
  Base64.strict_encode64(File.binread('app/public/favicon.ico'))
end

get "/merritt_logo.jpg" do
  content_type 'image/jpeg'
  Base64.strict_encode64(File.binread('app/public/merritt_logo.jpg'))
end