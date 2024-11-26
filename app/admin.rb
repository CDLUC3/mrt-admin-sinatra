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
