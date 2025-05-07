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
        erb :table,
          :layout => :page_layout,
          :locals => {
            context: AdminUI::Context.new(request.path),
            table: ldap.users_table
          }
      end

      app.get '/ldap/users/*' do
        user = params[:splat][0]
        ldap = UC3Ldap::LDAPClient.client
        ldap.load
        roles = ldap.user_detail_records(user)
        erb :table,
          :layout => :page_layout,
          :locals => {
            context: AdminUI::Context.new(request.path),
            table: ldap.user_details_table(roles)
          }
      end

      app.get '/ldap/collections/*' do
        coll = params[:splat][0]
        ldap = UC3Ldap::LDAPClient.client
        ldap.load
        roles = ldap.collection_detail_records(coll)
        erb :table,
          :layout => :page_layout,
          :locals => {
            context: AdminUI::Context.new(request.path),
            table: ldap.collection_details_table(roles)
          }
      end

      app.get '/ldap/collections' do
        ldap = UC3Ldap::LDAPClient.client
        ldap.load
        erb :table,
          :layout => :page_layout,
          :locals => {
            context: AdminUI::Context.new(request.path),
            table: ldap.collections_table
          }
      end

      app.get '/ldap/roles' do
        ldap = UC3Ldap::LDAPClient.client
        ldap.load
        erb :table,
          :layout => :page_layout,
          :locals => {
            context: AdminUI::Context.new(request.path),
            table: ldap.roles_table
          }
      end

      app.get '/ldap/collections-missing' do
        erb :table,
          :layout => :page_layout,
          :locals => {
            context: AdminUI::Context.new(request.path),
            table: UC3Ldap::LDAPCollectionMapList.new.ldap_collection_map
          }
      end
    end
  end
  register UC3LdapRoutes
end
