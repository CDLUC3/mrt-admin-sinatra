# frozen_string_literal: true

require 'sinatra'
require 'sinatra/base'
require_relative 'lib/routes/code'

set :bind, '0.0.0.0'

puts "ENV: #{ENV}"

# sinatra routes
module Sinatra
  # modularize route handling by specific clients
  include UC3CodeRoutes

  get '/context' do |repo|
    erb :table,
      :layout => :page_layout,
      :locals => {
        context: AdminUI::Context.new("Admin Tool Context"),
        table: srccode.repo_tags(repo)
      }
  end
end
