# frozen_string_literal: true

# Web context for the UI
class Context
  def initialize(title, top_page: false)
    @title = title
    @top_page = top_page
    @breadcrumbs = []
  end

  attr_accessor :top_page, :breadcrumbs, :title
end
