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
      @top = parent.nil? ? self : parent.top
      @top.paths[path] = self
      @children = []
    end

    attr_accessor :title, :parent, :top, :children, :path

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
      child
    end

    def add_menu_item(route, title, description: '')
      mi = MenuItem.new(self, route, title, description: description)
      @children << mi
      mi
    end

    # https://www.w3schools.com/howto/howto_css_dropdown_navbar.asp
    def render
      s = %(
        <!-- Menu #{@path} -->
        <div class="dropdown">
          <button class="dropbtn">
            <span>#{title}</span>
            <i class="fa fa-caret-down"></i>
          </button>
      )
      unless children.empty?
        s += %(<div class="dropdown-content">)
        children.each do |item|
          s += item.render
        end
        s += %(</div>)
      end
      s += %(</div>)
      s
    end
  end

  ## Top menu bar
  # contains a hash of menu paths to menus
  # contains a hash of normalized routes to page names and descriptions
  class TopMenu < Menu
    def create_menu_for_path(path, title)
      parpath = File.dirname(path)
      if @paths.key?(parpath)
        @paths[parpath].add_submenu(path, title)
      else
        parpath = File.dirname(path) until @paths.key?(parpath)
        @paths[parpath].add_submenu(path, path)
        create_menu_for_path(path, title)
      end
    end

    def create_menu_item_for_path(path, route, title, description: '')
      parpath = File.dirname(path)
      if @paths.key?(parpath)
        @paths[parpath].add_menu_item(route, title, description: description)
      else
        parpath = File.dirname(path) until @paths.key?(parpath)
        @paths[parpath].add_submenu(path, path)
        create_menu_for_path(path, title).add_menu_item(route, title, description: description)
      end
    end

    def initialize
      @paths = {}
      @route_names = {}
      super('/', '/', parent: nil)
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
    def initialize(parent, route, title, description: '')
      @parent = parent
      @title = title
      @route = route
      @description = description
      @parent.top.route_names[route_normalized] = { title: title, description: description }
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
