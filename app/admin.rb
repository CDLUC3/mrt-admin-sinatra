# frozen_string_literal: true

require 'sinatra'
require 'sinatra/base'
require_relative 'lib/routes/code'

set :bind, '0.0.0.0'

# sinatra routes
module Sinatra
  # modularize route handling by specific clients
  include UC3CodeRoutes
end
