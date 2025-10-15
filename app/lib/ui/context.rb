# frozen_string_literal: true

require 'redcarpet'

# admin ui components
module AdminUI
  MENU_ROOT = '/'
  MENU_HOME = '/home'
  MENU_SOURCE = '/source'
  MENU_RESOURCES = '/resources'
  MENU_QUERY = '/queries'

  ## Menu (array of submenus and menu items)
  class Menu
    def initialize(path, title, parent: nil, classes: '')
      @path = path
      @title = title
      @parent = parent
      @depth = parent.nil? ? 1 : parent.depth + 1
      @top = parent.nil? ? self : parent.top
      @top.paths[path] = self
      @children = []
      @classes = classes
    end

    attr_accessor :title, :parent, :top, :children, :path, :depth, :classes

    def full_path
      paths = []
      current = self
      paths << path
      while current.parent
        current = current.parent
        paths << current.path
      end
      paths.reverse.join('/')
    end

    def add_submenu(path, title, breadcrumb: false, description: '', route: '', classes: '')
      child = Menu.new(path, title, parent: self, classes: classes)
      if breadcrumb && !route.empty?
        child.top.route_names[route] =
          { title: title, description: description, breadcrumb: true, route: route }
      end
      @children << child
      child
    end

    def add_menu_item(route, title, description: '', tbd: false, breadcrumb: false, external: false, method: 'get',
      confmsg: '', classes: '')
      mi = MenuItem.new(self, route, title, description: description, tbd: tbd, breadcrumb: breadcrumb,
        external: external, method: method, confmsg: confmsg, classes: classes)
      @children << mi
      mi
    end

    def render
      s = %(
      <li role="none" class="#{classes}">
        <a aria-haspopup="true" aria-expanded="false" href="#" role="menuitem" title="#{title}">#{title}</a>
        <ul class="submenu" role="menu" aria-label="#{title} submenu">
      )
      children.each do |item|
        s += item.render
      end
      s += %(
      </ul>
      </li>
      )
      s
    end
  end

  ## Top menu bar
  # contains a hash of menu paths to menus
  # contains a hash of normalized routes to page names and descriptions
  class TopMenu < Menu
    def self.instance
      @instance ||= TopMenu.new
      @instance
    end

    def create_menu_item_for_path(path, route, title, description: '', tbd: false, breadcrumb: false, menu: false,
      external: false, method: 'get', confmsg: '', classes: '')
      parpath = path
      if @paths.key?(parpath)
        if menu
          @paths[parpath].add_submenu(path, title, description: description, breadcrumb: breadcrumb, route: route,
            classes: classes)
        else
          @paths[parpath].add_menu_item(route, title, description: description, tbd: tbd, breadcrumb: breadcrumb,
            external: external, method: method, confmsg: confmsg, classes: classes)
        end
      else
        parpath = File.dirname(path) until @paths.key?(parpath)
        if menu
          @paths[parpath].add_submenu(path, title, description: description, breadcrumb: breadcrumb, route: route,
            classes: classes)
        else
          @paths[parpath].add_submenu(path, path, breadcrumb: breadcrumb, route: route, classes: classes)
          create_menu_item_for_path(path, route, title, description: description, tbd: tbd, breadcrumb: breadcrumb,
            menu: menu, external: external, method: method, confmsg: confmsg, classes: classes)
        end
      end
    end

    def initialize
      @paths = {}
      @route_names = {}
      super('/', '', parent: nil)
    end

    attr_accessor :paths, :route_names

    def breadcrumbs_for_route(route)
      breadcrumbs = []
      while route != '/'
        route = File.dirname(route)
        breadcrumbs << { title: @route_names[route][:title], url: route } if @route_names.key?(route)
      end
      breadcrumbs.reverse
    end

    def description_for_route(route)
      desc = ''
      if @route_names.key?(route)

        desc = @route_names[route].fetch(:description, '')
        if @route_names[route].fetch(:breadcrumb, false) && desc.empty?
          @route_names.each do |key, value|
            next unless File.dirname(key) == route

            desc += if %w[post delete].include?(value[:method])
                      "\n- #{value[:title]} ⚙️"
                    else
                      "\n- [#{value[:title]}](#{value[:route]})"
                    end
          end
        end
      end
      desc
    end

    def render
      s = %(
      <nav>
      <ul class="menu" role="menubar">
      )
      children.each do |item|
        s += item.render
      end
      s += %(
      <li class="search">
        <span class="search">
        <form action="/search" method="post" class="search">
        <label for="search">Search: </label>
        <select id="search_type" class="search" name="search_type">
          <option value="ark">Ark</option>
          <option value="inv_object_id">inv_object_id</option>
          <option value="localid">Local Id</option>
          <option value="erc_what">erc_what</option>
          <option value="erc_who">erc_who</option>
          <option value="erc_when">erc_when</option>
          <option value="filename">filename</option>
          <option value="container">container</option>
        </select>
        <input id="search"class="search" name="search" type="text" width="25" value=""/>
        <input type="submit" value="Go" />
        </form>
        </span>
      </li>
      </ul>
      </nav>
      )
      s
    end
  end

  ## Menu item (hash of title, description and full route (path and query string)
  class MenuItem
    def initialize(parent, route, title, description: '', tbd: false, breadcrumb: false, external: false,
      method: 'get', confmsg: '', classes: '')
      @parent = parent
      @title = title
      @route = route
      @tbd = tbd
      @external = external
      @method = method
      @breadcrumb = breadcrumb
      @description = description
      @confmsg = confmsg
      @classes = classes

      @parent.top.route_names[route_normalized] =
        { title: title, description: description, route: @route, method: @method }
    end

    attr_accessor :title, :route, :description, :tbd, :breadcrumb, :external, :method, :confmsg, :classes

    def route_normalized
      arr = @route.split('?')
      return @route if arr.length == 1

      arr[1] = arr[1].gsub('/', '_')
      arr.join('?')
    end

    def render
      return '' if @breadcrumb

      carr = @classes.split
      carr << 'tbd' if @tbd
      lclass = carr.join(' ')
      if @method == 'get'
        icon = @external ? ' 🔗' : ''
        target = @external ? '_blank' : '_self'
        %(
          <li role="none">
            <a role="menuitem"
              class="#{lclass}"
              href="#{route}"
              title="#{title}"
              target="#{target}"
            >
            <span>#{title}#{icon}</span>
            </a>
          </li>
        )
      else
        icon = ' ⚙️'
        %(
          <li role="none">
            <a role="none"
              class="post-link"
              data-route="#{route}"
              confmsg="#{confmsg}"
              title="#{title}"
            >
            <span>#{title}#{icon}</span>
            </a>
          </li>
        )
      end
    end
  end

  # Web context for the UI
  class Context
    @css = 'empty.css'
    @index_md = 'app/markdown/uc3/index.md'
    class << self
      attr_accessor :css, :index_md
    end

    def initialize(route, title: nil)
      @route = route
      page = TopMenu.instance.route_names[route]
      deftitle = title || File.basename(route).capitalize
      @title = page ? page.fetch(:title, deftitle) : deftitle
      @description = TopMenu.instance.description_for_route(@route)
      @breadcrumbs = breadcrumbs
      # Breadcrumbs are an array of hashes with keys :title and :url

      @ctime = if File.exist?('/var/tast/Gemfile.lock')
                 File.ctime('/var/task/Gemfile.lock').strftime('%Y%m%d_%H%M%S')
               else
                 Time.now.strftime('%Y%m%d_%H%M%S')
               end
    end

    def classes
      classes = []
      begin
        classes << 'no-db' unless UC3Query::QueryClient.client.enabled
        classes << 'no-zk' unless UC3Queue::ZKClient.client.enabled || UC3::UC3Client.dbsnapshot_stack?
        classes << 'no-ldap' unless UC3Ldap::LDAPClient.client.enabled
      rescue StandardError
        # allow clients to be commented out for debugging
      end
      classes
    end

    def breadcrumbs
      TopMenu.instance.breadcrumbs_for_route(@route)
    end

    def description
      description = Redcarpet::Markdown.new(Redcarpet::Render::HTML.new, fenced_code_blocks: true).render(@description)
      Mustache.render(description, ENV)
    end

    def to_h
      {
        title: @title,
        route: @route,
        description: @description
      }
    end

    attr_accessor :title, :route, :ctime
  end
end
