# frozen_string_literal: true
require_relative '../ui/table'

# Scope custom code for UC3 to distinguish from 3rd party classes
module UC3
  # Base class for UC3 client classes
  class UC3Client
    def enabled
      false
    end

    def context
      table = AdminUI::FilterTable.new(
        columns: [
          AdminUI::Column.new(:key, header: 'Key'),
          AdminUI::Column.new(:value, header: 'Value')
        ]
      )
      ENV.sort.each do |key, value|
        v = key =~ /(KEY|TOKEN|SECRET)/ ? '***' : value
        table.add_row(AdminUI::Row.make_row(table.columns, {key: key, value: v}))
      end
      if $context
        table.add_row(AdminUI::Row.make_row(table.columns, {key: 'Context', value: $context.pretty_inspect}))
      end
      table
    end
  end
end
