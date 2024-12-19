# frozen_string_literal: true

# admin ui components
module AdminUI

  MENU_ROOT = '/'
  MENU_HOME = '/home'
  MENU_SOURCE = '/source'
  MENU_RESOURCES = '/resources'
  MENU_QUERY = '/query'

  # Web context for the UI
  class Context
    @@menu = {}
    @@titles = {}

    def initialize(path, title: nil)
      @path = path
      @title = @@titles[path] || title || path
      # Breadcrumbs are an array of hashes with keys :title and :url
    end

    def self.add_menu_item(path, title, url = '')
      if url.empty?
        @@titles[path] = title
      else
        return if @@titles.key?(url)
      
        @@menu[path] = [] unless @@menu.key?(path)
        @@menu[path] << { path: path, title: title, url: url }
        @@titles[url] = title
      end
    end

    def self.menu
      @@menu
    end

    def self.titles
      @@titles
    end

    def self.render_menu
      s = %{
      <header>
        <div class="navbar">
      } 
      self.child_paths(MENU_ROOT).each do |item|
        path = item[:path]
        s += render_menu_group(path, @@menu[path])
      end
      s += %{
        </div>
      </header>
      }
      s
    end

    def self.child_paths(path)
      children = []
      return children if path.nil?
      return children if path.empty?
      
      @@menu.sort.each do |key, _v|
        next if key == path
        next unless File.dirname(key) == path

        n = @@menu[key]
        if n.instance_of?(Array)
          children << { path: key, title: path }
        else
          children << n
        end
      end
      children
    end

    def self.render_menu_group(path, arr)
      s = %{
        <div class="dropdown">
          <button class="dropbtn">
            <span>#{@@titles.fetch(path, path)}</span>
            <i class="fa fa-caret-down"></i>
          </button>
          <div class="dropdown-content">
      }
      arr.each do |item|
        children = self.child_paths(item.fetch(:path, ''))
        if children.empty?
          s += render_menu_item(item)
        else
          s += render_menu_group(item[:path], children)
        end
    end
      s += %{</div></div>}
      s
    end

    def self.render_menu_item(item)
      return '' if item.nil?
      %{<a href="#{item[:url]}">#{item[:title]}</a>}
    end

    def breadcrumbs
      breadcrumbs = []
      path = @path
      while path != '/'
        path = File.dirname(path)
        breadcrumbs << { title: @@titles[path], url: path } if @@titles.key?(path)
      end
      breadcrumbs.reverse
    end

    attr_accessor :title, :path
  end
end
