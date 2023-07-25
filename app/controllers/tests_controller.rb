class TestsController < ApplicationController
  def index
    render json: { ok: true, enhanced_structured_logging_rails: EnhancedStructuredLoggingRails::VERSION }
  end
end
