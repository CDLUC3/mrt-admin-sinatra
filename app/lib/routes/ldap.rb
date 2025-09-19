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

      app.get '/ldap/collections/details/*' do
        coll = params[:splat][0]
        ldap = UC3Ldap::LDAPClient.client
        ldap.load
        roles = ldap.collection_detail_records(coll)

        adminui_show_table(
          AdminUI::Context.new(request.path),
          ldap.collection_details_table(coll, roles)
        )
      end

      app.get '/ldap/collections/edit/*' do
        coll = params[:splat][0]
        ldap = UC3Ldap::LDAPClient.client
        ldap.load
        perms = ldap.collection_perm_records(coll)

        erb :colladmin_collection_roles, layout: :page_layout, locals: {
          context: AdminUI::Context.new(request.path),
          collection: coll,
          perms: perms
        }
      end

      app.get '/ldap/collections' do
        ldap = UC3Ldap::LDAPClient.client
        ldap.load
        adminui_show_table(
          AdminUI::Context.new(request.path),
          ldap.collections_table
        )
      end

      app.get '/ldap/collections-missing' do
        ldap = UC3Ldap::LDAPClient.client
        ldap.load
        adminui_show_table(
          AdminUI::Context.new(request.path),
          UC3Ldap::LDAPCollectionMapList.new(ldap).ldap_collection_map(request.path)
        )
      end

      app.post '/ldap/create-collection-groups' do
        ldap = UC3Ldap::LDAPClient.client
        coll = ldap.create_collection_groups(request.body.read)
        content_type :json
        coll.to_json
      end
    end
  end
  register UC3LdapRoutes
end
