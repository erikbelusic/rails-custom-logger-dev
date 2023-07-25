# frozen_string_literal: true

require "active_support"
require "active_support/core_ext"
require_relative "enhanced_structured_logging_rails/version"
require_relative "enhanced_structured_logging_rails/json_formatter"
require_relative "enhanced_structured_logging_rails/tagged_and_contextual_logging"

module EnhancedStructuredLoggingRails
  class UnsupportedFormatterError < StandardError; end

  def self.dump_json(hash)
    hash.to_json
  end
end
