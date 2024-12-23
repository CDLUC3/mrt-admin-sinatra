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
      @depth = parent.nil? ? 1 : parent.depth + 1
      @top = parent.nil? ? self : parent.top
      @top.paths[path] = self
      @children = []
    end

    attr_accessor :title, :parent, :top, :children, :path, :depth

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

    def class_name
      case @depth
      when 1
        'top-level-menu'
      when 2
        'second-level-menu'
      when 3
        'third-level-menu'
      else
        'fourth-level-menu'
      end
    end

    def render
      s = ''
      s += %(<li><a href="#">#{title}</a>) unless title.empty?
      s += %(<ul class="#{class_name}">)
      children.each do |item|
        s += item.render
      end
      s += %(</ul>)
      s += %(</li>) unless title.empty?
      s
    end
  end

  ## Top menu bar
  # contains a hash of menu paths to menus
  # contains a hash of normalized routes to page names and descriptions
  class TopMenu < Menu
    def create_menu_for_path(path, title)
      parpath = path
      if @paths.key?(parpath)
        @paths[parpath].add_submenu(path, title)
      else
        parpath = File.dirname(path) until @paths.key?(parpath)
        @paths[parpath].add_submenu(path, path)
        create_menu_for_path(path, title)
      end
    end

    def create_menu_item_for_path(path, route, title, description: '')
      parpath = path
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
      %(<li><a href="#{route}">#{title}</a></li>)
    end
  end

  # Web context for the UI
  class Context
    def self.topmenu
      unless @topmenu
        @topmenu = TopMenu.new
        @topmenu.add_submenu(MENU_HOME, 'Home')
        @topmenu.add_submenu(MENU_SOURCE, 'Source')
        @topmenu.add_submenu(MENU_RESOURCES, 'Resources')
        @topmenu.add_submenu(MENU_QUERY, 'Queries')
        @topmenu.add_submenu('/test', 'Test')
      end
      @topmenu
    end

    def initialize(route, title: nil)
      @route = route
      page = Context.topmenu.route_names[route]
      deftitle = title || route
      @title = page ? page.fetch(:title, deftitle) : deftitle
      @breadcrumbs = breadcrumbs
      # Breadcrumbs are an array of hashes with keys :title and :url
    end

    def breadcrumbs
      Context.topmenu.breadcrumbs_for_route(@route)
    end

    attr_accessor :title, :route
  end
end
