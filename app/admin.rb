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
  send_file 'public/favicon.ico', type: 'image/x-icon'
end

get "/merritt_logo.jpg" do
  send_file 'public/favicon.ico', type: 'image/jpeg'
end