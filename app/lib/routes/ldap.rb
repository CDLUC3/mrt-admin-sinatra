# frozen_string_literal: true

require 'sinatra/base'
require 'uri'
require_relative '../client/ldap/ldap'
require_relative '../ui/context'

# custom sinatra routes
module Sinatra
  # client specific routes
  module UC3LdapRoutes
    def self.registered(app)
      app.get '/ldap' do
        ldap = UC3Ldap::LDAPClient.client
        ldap.load_users
        erb :none,
          :layout => :page_layout,
          :locals => {
            context: AdminUI::Context.new(request.path),
            table: ldap.users.table,
          }
      end

    end
  end
  register UC3LdapRoutes
end
