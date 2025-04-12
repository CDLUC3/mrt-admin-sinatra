require 'net/ldap'

module UC3Ldap
  # LDAP Client
  class LDAPClient < UC3::UC3Client
    def self.client
      UC3::UC3Client.clients.fetch(self.class.to_s, LDAPClient.new)
    end

    def initialize
      @ldapconf = UC3::UC3Client.load_config('app/config/mrt/ldap.yml')
      @ldap_connect = {
        host: @ldapconf.fetch('host', ''),
        port: @ldapconf.fetch('port', '1389').to_i,
        auth: {
          method: :simple,
          username: @ldapconf.fetch('admin_user', ''),
          password: @ldapconf.fetch('admin_password', '')
        },
        connect_timeout: @ldapconf.fetch('connect_timeout', '60').to_i
      }
      if @ldapconf.fetch('encryption', '') == 'simple_tls'
        @ldap_connect[:encryption] = {
          method: :simple_tls,
          tls_options: {
            ssl_version: @ldapconf.fetch('tls', 'TLSv1_2')
          }
        }
      end
      @ldap = Net::LDAP.new(@ldap_connect)
      super(enabled: enabled)
    rescue StandardError => e
      puts "#{e.class}: #{e}; #{e.backtrace.join("\n")}"
      super(enabled: false, message: e.to_s)
    end

    def enabled
      !@client.nil?
    end

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
          LambdaBase.log("Not found: [#{role.coll}]")
        end
        role.set_collection(coll)
  
        role.users.each do |u|
          user = nil
          if @users.key?(u)
            user = @users[u]
          else
            LambdaBase.log("Not found: [#{u}]")
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
  
    def normalize_dn(s)
      s.gsub(',', '/').gsub('cn=', '').gsub('ou=', '').gsub('dc=', '').gsub('uid=', '')
    end
  
    def format(attr, v)
      if attr == 'uniquemember'
        str = ''
        v.entries.each do |entry|
          str = "#{str}," unless str.empty?
          str = "#{str}#{normalize_dn(entry)}"
        end
        return str
      end
      v = normalize_dn(v.to_s) if %w[uniquemember dn].include?(attr)
      v
    end

    class LdapRecord
      def initialize
        # reserve
      end
    
      def find_part(entry, part, defval)
        part = "#{part}="
        entry.to_s.split(',').each do |s|
          return s[part.length, s.length] if s.start_with?(part)
        end
        LambdaBase.log("Part not found in [#{entry}], Part[#{part}]")
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
        LambdaBase.log("Part not found in [#{entry}], Part[#{part}]")
        defval
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
        "#{@displayname.nil? ? '' : @displayname.gsub(',', '')} (#{uid})"
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
    
      def table
      end
      
      def table_row
        [
          @uid,
          unlinked,
          @email,
          displayname,
          @arkid,
          @lastaccess,
          perm_count('read'),
          perm_count('write'),
          perm_count('download'),
          perm_count('admin')
        ]
      end
    
      def self.get_headers
        [
          'User Id',
          'Unlinked',
          'Email',
          'Display Name',
          'Ark',
          'Last Access',
          'Read',
          'Write',
          'Download',
          'Admin'
        ]
      end
    
      def self.get_types
        [
          'ldapuid',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          ''
        ]
      end
    end
  end
end