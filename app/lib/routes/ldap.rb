# frozen_string_literal: true

require 'sinatra/base'
require 'uri'
require_relative '../client/ldap/ldap'
require_relative '../client/ldap/ldapmap'
require_relative '../ui/context'

# custom sinatra routes
module Sinatra
  # client specific routes
  module UC3LdapRoutes
    def self.registered(app)
      app.get '/ldap/users' do
        ldap = UC3Ldap::LDAPClient.client
        ldap.load

        adminui_show_table(
          AdminUI::Context.new(request.path),
          ldap.users_table
        )
      end

      app.get '/ldap/users/*' do
        user = params[:splat][0]
        ldap = UC3Ldap::LDAPClient.client
        ldap.load
        roles = ldap.user_detail_records(user)

        adminui_show_table(
          AdminUI::Context.new(request.path),
          ldap.user_details_table(roles)
        )
      end

      app.get '/ldap/collections/*' do
        coll = params[:splat][0]
        ldap = UC3Ldap::LDAPClient.client
        ldap.load
        roles = ldap.collection_detail_records(coll)

        adminui_show_table(
          AdminUI::Context.new(request.path),
          ldap.collection_details_table(roles)
        )
      end

      app.get '/ldap/collections' do
        ldap = UC3Ldap::LDAPClient.client
        ldap.load
        adminui_show_table(
          AdminUI::Context.new(request.path),
          ldap.collections_table
        )
      end

      app.get '/ldap/roles' do
        ldap = UC3Ldap::LDAPClient.client
        ldap.load
        adminui_show_table(
          AdminUI::Context.new(request.path),
          ldap.roles_table
        )
      end

      app.get '/ldap/collections-missing' do
        adminui_show_table(
          AdminUI::Context.new(request.path),
          UC3Ldap::LDAPCollectionMapList.new.ldap_collection_map(request.path)
        )
      end
    end
  end
  register UC3LdapRoutes
end
