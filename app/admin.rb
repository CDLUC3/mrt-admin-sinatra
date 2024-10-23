require 'sinatra'
require 'sinatra/base'

helpers do

get "/" do
  status 200
  erb :index
end