# frozen_string_literal: true

# Scope custom code for UC3 to distinguish from 3rd party classes
module UC3
  # Base class for UC3 client classes
  class UC3Client
    def enabled
      false
    end
  end
end
