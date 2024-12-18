# frozen_string_literal: true

# admin ui components
module AdminUI
  # Web context for the UI
  class Context
    def initialize(title, top_page: false, breadcrumbs: []) 
      @title = title
      @top_page = top_page
      # Breadcrumbs are an array of hashes with keys :title and :url
      @breadcrumbs = breadcrumbs
    end

    attr_accessor :top_page, :breadcrumbs, :title
  end
end
