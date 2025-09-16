# frozen_string_literal: true

require 'net/ldap'

module UC3Ldap
  # LDAP Client
  class LDAPClient < UC3::UC3Client
    def self.client
      UC3::UC3Client.clients.fetch(self.class.to_s, LDAPClient.new)
    end

    def initialize
      @users = {}
      @collections = {}
      @collection_arks = {}
      @roles = {}

      @ldapconf = UC3::UC3Client.lookup_map_by_filename(
        'app/config/mrt/ldap.lookup.yml',
        key: ENV.fetch('configkey', 'default'),
        symbolize_names: true
      )

      # puts "LDAP HOST: #{@ldapconf.fetch(:host, '')}:#{@ldapconf.fetch(:port, '1389')}"
      @ldap_connect = {
        host: @ldapconf.fetch(:host, ''),
        port: @ldapconf.fetch(:port, '1389').to_i,
        auth: {
          method: :simple,
          username: @ldapconf.fetch(:admin_user, ''),
          password: @ldapconf.fetch(:admin_password, '')
        },
        connect_timeout: @ldapconf.fetch(:connect_timeout, '60').to_i
      }
      if @ldapconf.fetch(:encryption, '') == 'simple_tls'
        @ldap_connect[:encryption] = {
          method: :simple_tls,
          tls_options: {
            ssl_version: @ldapconf.fetch('tls', 'TLSv1_2')
          }
        }
      end
      @ldap = Net::LDAP.new(@ldap_connect, onerror: 'warn')

      @ldap.bind
      super(enabled: true)
    rescue Errno::ECONNREFUSED => e
      puts "(LDAP Conn Refused) #{e.class}: #{e};"
      super(enabled: false, message: e.to_s)
    rescue StandardError => e
      puts "(LDAP) #{e.class}: #{e};"
      super(enabled: false, message: e.to_s)
    end

    attr_reader :users, :collections, :collection_arks, :roles

    def user_displayname(uid)
      return uid unless @users.key?(uid)

      @users[uid].displayname
    end

    def user_detail_records(uid)
      return [] unless @users.key?(uid)

      @users.fetch(uid).detail_records
    end

    def coll_displayname(coll)
      return col unless @collections.key?(coll)

      @collections[coll].description
    end

    def collection_detail_records(coll)
      return [] unless @collections.key?(coll)

      @collections.fetch(coll).detail_records
    end

    def collection_detail_records_for_ark(ark)
      return [] unless @collection_arks.key?(ark)

      @collection_arks.fetch(ark).detail_records
    end

    def user_base
      @ldapconf.fetch('user_base', '')
    end

    def group_base
      @ldapconf.fetch('group_base', '')
    end

    def load
      load_users
      load_collections
      load_roles
    end

    def load_users
      attr = %i[
        dn objectclass mail sn tzregion cn arkid givenname userpassword displayname uid
        ds-pwp-last-login-time
      ]
      @ldap.search(base: user_base, attributes: attr) do |entry|
        user = LdapUser.new(entry)
        next if user.uid.nil?
        next if user.uid.empty?

        @users[user.uid] = user
      end
    end

    def load_collections
      @ldap.search(base: group_base, filter: Net::LDAP::Filter.eq('arkId', '*')) do |entry|
        coll = LdapCollection.new(entry)
        @collections[coll.mnemonic] = coll
        @collection_arks[coll.ark] = coll
      end
    end

    def load_roles
      @ldap.search(base: group_base, filter: Net::LDAP::Filter.eq('uniquemember', '*')) do |entry|
        role = LdapRole.new(entry)
        coll = nil
        if @collections.key?(role.coll)
          coll = @collections[role.coll]
          coll.add_role(role, role.users.length)
        else
          coll = LdapCollection.new(nil, role.coll)
          @collections[role.coll] = coll
          puts "LDAP: Not found: [#{role.coll}]"
        end
        role.set_collection(coll)

        role.users.each do |u|
          user = nil
          if @users.key?(u)
            user = @users[u]
          else
            puts "LDAP: Not found: [#{u}]"
            user = LdapUser.new(nil, u)
            @users[u] = user
          end
          role.add_user(user)
          user.add_role(role, 1)
        end
        @roles[role.dn] = role
      end
    end

    # https://github.com/CDLUC3/mrt-dashboard/blob/master/app/lib/group_ldap.rb
    # https://github.com/CDLUC3/mrt-dashboard/blob/master/app/lib/institution_ldap.rb
    # https://github.com/CDLUC3/mrt-dashboard/blob/master/app/lib/user_ldap.rb
    # roles: cn,dn,objectclass,uniquemember
    # users: dn,objectclass,mail,sn,tzregion,cn,arkid,givenname,telephonenumber,userpassword,displayname,uid
    def search(treebase, ldapattrs)
      rows = []

      @ldap.search(base: treebase) do |entry|
        row = []
        ldapattrs.each do |attr|
          v = format(attr, entry[attr])
          row.append(v)
        end
        rows.append(row)
      end
      rows
    end

    def normalize_dn(dispname)
      dispname.gsub(',', '/').gsub('cn=', '').gsub('ou=', '').gsub('dc=', '').gsub('uid=', '')
    end

    def format(attr, val)
      if attr == 'uniquemember'
        str = ''
        val.entries.each do |entry|
          str = "#{str}," unless str.empty?
          str = "#{str}#{normalize_dn(entry)}"
        end
        return str
      end
      val = normalize_dn(v.to_s) if %w[uniquemember dn].include?(attr)
      val
    end

    def users_table_data
      arr = []
      @users.each_value do |user|
        arr.append({
          uid: { value: user.uid, href: "/ldap/users/#{user.uid}" },
          unlinked: user.unlinked,
          email: user.email,
          displayname: user.displayname,
          arkid: user.ark,
          lastaccess: user.lastaccess,
          read_count: user.read_count,
          write_count: user.write_count,
          download_count: user.download_count,
          admin_count: user.admin_count
        })
      end
      arr
    end

    def users_table
      table = AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:uid, header: 'User id'),
          AdminUI::Column.new(:unlinked, header: 'Unlinked'),
          AdminUI::Column.new(:email, header: 'Email'),
          AdminUI::Column.new(:displayname, header: 'Display Name'),
          AdminUI::Column.new(:arkid, header: 'Ark'),
          AdminUI::Column.new(:lastaccess, header: 'Last Access'),
          AdminUI::Column.new(:read_count, header: 'Read Count'),
          AdminUI::Column.new(:write_count, header: 'Write Count'),
          AdminUI::Column.new(:download_count, header: 'Download Count'),
          AdminUI::Column.new(:admin_count, header: 'Admin Count')
        ]
      )
      users_table_data.each do |user|
        table.add_row(AdminUI::Row.make_row(table.columns, user))
      end
      table
    end

    def collections_table_data
      arr = []
      @collections.each_value do |coll|
        arr.append({
          mnemonic: { value: coll.mnemonic, href: "/ldap/collections/#{coll.mnemonic}" },
          unlinked: coll.unlinked,
          description: coll.description,
          profile: coll.profile,
          arkid: coll.ark,
          read_count: coll.read_count,
          write_count: coll.write_count,
          download_count: coll.download_count,
          admin_count: coll.admin_count
        })
      end
      arr
    end

    def collections_table
      table = AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:mnemonic, header: 'Mnemonic'),
          AdminUI::Column.new(:unlinked, header: 'Unlinked'),
          AdminUI::Column.new(:arkid, header: 'Ark'),
          AdminUI::Column.new(:description, header: 'Description'),
          AdminUI::Column.new(:profile, header: 'Profile'),
          AdminUI::Column.new(:read_count, header: 'Read Count'),
          AdminUI::Column.new(:write_count, header: 'Write Count'),
          AdminUI::Column.new(:download_count, header: 'Download Count'),
          AdminUI::Column.new(:admin_count, header: 'Admin Count')
        ]
      )
      collections_table_data.each do |coll|
        table.add_row(AdminUI::Row.make_row(table.columns, coll))
      end
      table
    end

    def roles_table
      table = AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:perm, header: 'Permission'),
          AdminUI::Column.new(:collection_name, header: 'collection'),
          AdminUI::Column.new(:user_names, header: 'Users')
        ]
      )
      roles.each_value do |role|
        table.add_row(AdminUI::Row.make_row(table.columns, {
          perm: role.perm,
          collection_name: role.collection_name,
          user_names: role.user_names
        }))
      end
      table
    end

    def user_details_table(roles)
      table = AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:collection, header: 'Collection'),
          AdminUI::Column.new(:read, header: 'Read'),
          AdminUI::Column.new(:write, header: 'Write'),
          AdminUI::Column.new(:download, header: 'Download'),
          AdminUI::Column.new(:admin, header: 'Admin')
        ]
      )
      roles.each_value do |role|
        table.add_row(AdminUI::Row.make_row(table.columns, {
          collection: { value: role.collection, href: "/ldap/collections/#{role.collection}" },
          read: role.read,
          write: role.write,
          download: role.download,
          admin: role.admin
        }))
      end
      table
    end

    def collection_details_table(roles)
      table = AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:user, header: 'User'),
          AdminUI::Column.new(:read, header: 'Read'),
          AdminUI::Column.new(:write, header: 'Write'),
          AdminUI::Column.new(:download, header: 'Download'),
          AdminUI::Column.new(:admin, header: 'Admin')
        ]
      )
      roles.each_value do |role|
        table.add_row(AdminUI::Row.make_row(table.columns, {
          user: { value: role.user, href: "/ldap/users/#{role.user}" },
          read: role.read,
          write: role.write,
          download: role.download,
          admin: role.admin
        }))
      end
      table
    end
  end

  # base class ldap record
  class LdapRecord
    def initialize
      # reserve
    end

    def find_part(entry, part, defval)
      part = "#{part}="
      entry.to_s.split(',').each do |s|
        return s[part.length, s.length] if s.start_with?(part)
      end
      puts "LDAP: Part not found in [#{entry}], Part[#{part}]"
      defval
    end
  end

  # ldap record linked to roles
  class LdapLinkedRecord < LdapRecord
    def initialize(islinked)
      @islinked = islinked
      @roles = []
      @perms = {}
      super()
    end

    def unlinked
      @islinked ? '' : 'unlinked'
    end

    def add_role(role, inc)
      @roles.append(role)
      @perms[role.perm] = perm_count(role.perm) + inc
    end

    def perm_count(perm)
      @perms.fetch(perm, 0)
    end

    def find_part(entry, part, defval)
      part = "#{part}="
      entry.to_s.split(',').each do |s|
        return s[part.length, s.length] if s.start_with?(part)
      end
      puts "LDAP: Part not found in [#{entry}], Part[#{part}]"
      defval
    end

    def read_count
      perm_count('read')
    end

    def write_count
      perm_count('write')
    end

    def download_count
      perm_count('download')
    end

    def admin_count
      perm_count('admin')
    end
  end

  # ldap user record
  class LdapUser < LdapLinkedRecord
    def initialize(entry, uid = '')
      if entry.nil?
        @uid = uid
        @email = ''
        @displayname = ''
        @arkid = ''
        @lastaccess = ''
        super(false)
      else
        @uid = entry['uid'].first
        @email = entry['mail']
        @displayname = entry['displayname'].first
        @arkid = entry['arkid']
        begin
          @lastaccess = entry['ds-pwp-last-login-time']
        rescue StandardError
          @lastaccess = 'na'
        end
        super(true)
      end
    end

    def displayname
      "#{@displayname&.gsub(',', '')} (#{uid})"
    end

    def ark
      @arkid.nil? ? '' : @arkid
    end

    def uid
      @uid.nil? ? '' : @uid
    end

    def detail_records
      LdapUserDetailed.load(self, @roles)
    end

    attr_reader :email, :arkid, :lastaccess
  end

  # ldap representation of a merritt collection
  class LdapCollection < LdapLinkedRecord
    def initialize(entry, mnemonic = '')
      if entry.nil?
        @ark_id = ''
        @description = ''
        @mnemonic = mnemonic
        @profile = ''
        super(false)
      else
        @ark_id = entry['arkId'].first
        @description = entry['description'].first
        @mnemonic = entry['ou'].first
        @profile = entry['submissionprofile'].first
        super(true)
      end
    end

    def ark
      @ark_id.nil? ? '' : @ark_id
    end

    def mnemonic
      @mnemonic.nil? ? '' : @mnemonic
    end

    def description
      @description.nil? ? '' : @description
    end

    def detail_records
      LdapCollectionDetailed.load(self, @roles)
    end

    attr_reader :ark_id, :profile
  end

  # ldap role
  class LdapRole < LdapRecord
    def initialize(entry)
      @dn = entry.dn
      @perm = entry['cn'].first
      @coll = find_part(entry.dn, 'ou', '')
      @users = []
      entry['uniquemember'].each do |role|
        u = find_part(role, 'uid', '')
        @users.append(u) unless u.empty?
      end
      @user_rec = []
      @collection_rec = nil
      super()
    end

    def set_collection(coll)
      @collection_rec = coll
    end

    def collection_name
      @collection_rec.nil? ? '' : "#{@collection_rec.description} (#{@collection_rec.mnemonic})"
    end

    attr_reader :users, :user_rec, :dn, :coll, :perm

    def add_user(user)
      @user_rec.append(user)
    end

    def user_names
      @names = []
      @user_rec.each do |user|
        @names.append(user.displayname.to_s)
      end
      @names.sort.join(',')
    end

    def role_description
      "#{@perm} - #{collection_name}"
    end
  end

  # detailed ldap information for a user including permissions
  class LdapUserDetailed < LdapRecord
    def self.load(_user, roles)
      colls = {}
      roles.each do |role|
        colls[role.coll] = {} unless colls.key?(role.coll)
        colls[role.coll][role.perm] = true
      end
      recs = {}
      colls.each do |coll, perms|
        recs[coll] = LdapUserDetailed.new(
          coll,
          perms.fetch('read', false),
          perms.fetch('write', false),
          perms.fetch('download', false),
          perms.fetch('admin', false)
        )
      end
      recs
    end

    def initialize(collection, read, write, download, admin)
      @collection = collection
      @read = read
      @write = write
      @download = download
      @admin = admin
      super()
    end

    attr_reader :collection, :read, :write, :download, :admin
  end

  # detailed ldap information for a collection including permissions
  class LdapCollectionDetailed < LdapRecord
    def self.load(_collection, roles)
      users = {}
      roles.each do |role|
        role.users.sort.each do |user|
          users[user] = {} unless users.key?(user)
          users[user][role.perm] = true
        end
      end
      recs = {}
      users.each do |user, perms|
        recs[user] = LdapCollectionDetailed.new(
          user,
          perms.fetch('read', false),
          perms.fetch('write', false),
          perms.fetch('download', false),
          perms.fetch('admin', false)
        )
      end
      recs
    end

    def initialize(user, read, write, download, admin)
      @user = user
      @read = read
      @write = write
      @download = download
      @admin = admin
      super()
    end

    attr_reader :user, :read, :write, :download, :admin
  end
end
