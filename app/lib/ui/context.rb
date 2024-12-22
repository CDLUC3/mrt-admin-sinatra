# frozen_string_literal: true

# admin ui components
module AdminUI
  MENU_ROOT = '/'
  MENU_HOME = '/home'
  MENU_SOURCE = '/source'
  MENU_RESOURCES = '/resources'
  MENU_QUERY = '/queries'

  ## Menu (array of submenus and menu items)
  class Menu
    def initialize(path, title, parent: nil)
      @path = path
      @title = title
      @parent = parent
      @top = parent.nil? ? self : parent
      @children = []
    end

    attr_accessor :title, :parent, :top, :children

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

    def add_submenu(path, title)
      child = Menu.new(path, title, parent: self)
      @children << child
      top.paths[path] = child
      child
    end

    def add_menu_item(route, title, description: '')
      mi = MenuItem.new(route, title, description: description)
      @children << mi
      top.route_names[mi.route_normalized] = { title: title, description: description }
      mi
    end

    def render
      s = %(
        <div class="dropdown">
          <button class="dropbtn">
            <span>#{title}</span>
            <i class="fa fa-caret-down"></i>
          </button>
          <div class="dropdown-content">
      )
      children.each do |item|
        s += item.render
      end
      s += %(</div></div>)
      s
    end
  end

  ## Top menu bar
  # contains a hash of menu paths to menus
  # contains a hash of normalized routes to page names and descriptions
  class TopMenu < Menu
    def self.create_menu_for_path(path, title)
      parpath = File.dirname(path)
      if @paths.key?(parpath)
        @paths[parpath].add_submenu(path, title)
      else
        parpath = File.dirname(path) until @paths.key?(parpath)
        @paths[parpath].add_submenu(path, path)
        create_menu_for_path(path, title)
      end
    end

    def initialize
      super('TOP', 'TOP', parent: nil)
      @paths = {}
      @route_names = {}
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

    def render
      s = %(
        <header>
          <div class="navbar">
        )
      children.reverse.each do |item|
        s += item.render
      end
      s += %(
          </div>
        </header>
        )
      s
    end
  end

  ## Menu item (hash of title, description and full route (path and query string)
  class MenuItem
    def initialize(route, title, description: '')
      @title = title
      @route = route
      @description = description
    end

    attr_accessor :title, :route, :description

    def route_normalized
      @route
    end

    def render
      %(<a href="#{route}">#{title}</a>)
    end
  end

  # Web context for the UI
  class Context
    def self.topmenu
      @topmenu ||= TopMenu.new
    end

    def initialize(route, title: nil)
      @route = route
      @title = Context.topmenu.route_names[route][:title] || title || route
      # Breadcrumbs are an array of hashes with keys :title and :url
    end

    def breadcrumbs
      Context.topmenu.breadcrumbs_for_route(@route)
    end

    attr_accessor :title, :route
  end
end
