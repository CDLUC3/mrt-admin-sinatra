# frozen_string_literal: true

require 'sinatra'
require 'sinatra/base'
require 'sinatra/contrib'

def adminui_show_table_format(context, table, format, erb: :table, locals: {}, aux_tables: [])
  halt 404, 'Not Found' if table.nil?

  case format
  when 'json'
    content_type :json
    {
      context: context.to_h,
      table: table.table_data,
      status: table.status,
      status_message: table.status_message
    }.to_json
  when 'csv'
    fname = "mrt-admin#{context.route.gsub('/', '-')}.#{Time.now.strftime('%Y%m%d-%H%M%S')}.csv"
    content_type 'text/csv', charset: 'utf-8'
    halt 200, { 'Content-Disposition' => "attachment; filename=\"#{fname}\"" },
      table.to_csv
  when 'text'
    content_type :text, encoding: 'utf-8'
    halt 200, table.to_csv
  else
    locals[:context] = context
    locals[:table] = table
    locals[:aux_tables] = aux_tables
    erb erb,
      :layout => :page_layout,
      :locals => locals
  end
end

def adminui_show_table(context, table, erb: :table, locals: {}, aux_tables: [])
  fmt = request.params.fetch('admintoolformat', '')
  adminui_show_table_format(context, table, fmt, erb: erb, locals: locals, aux_tables: aux_tables) unless fmt.empty?
  respond_to do |format|
    format.json do
      adminui_show_table_format(context, table, 'json', erb: erb, locals: locals, aux_tables: aux_tables)
    end
    format.html do
      adminui_show_table_format(context, table, 'html', erb: erb, locals: locals, aux_tables: aux_tables)
    end
  end
end

def adminui_show_markdown(context, md_file)
  respond_to do |format|
    format.html do
      erb :markdown,
        :layout => :page_layout,
        :locals => {
          md_file: md_file,
          context: context
        }
    end
    format.json do
      content_type :json
      {
        context: context.to_h,
        markdown: md_file
      }.to_json
    end
  end
end

def adminui_show_none(context)
  respond_to do |format|
    format.html do
      erb :none,
        :layout => :page_layout,
        :locals => {
          context: context
        }
    end
    format.json do
      content_type :json
      {
        context: context.to_h
      }.to_json
    end
  end
end
