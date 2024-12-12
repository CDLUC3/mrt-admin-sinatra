class Context
  def initialize(title, top_page: false)
    @title = title
    @top_page = top_page
    @breadcrumbs = []
  end
  
  attr_accessor :top_page, :breadcrumbs, :title
end