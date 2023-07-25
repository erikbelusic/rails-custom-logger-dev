# frozen_string_literal: true

module EnhancedStructuredLoggingRails
  class JsonFormatter < ::Logger::Formatter
    def initialize
      @datetime_format = "%Y-%m-%dT%H:%M:%S.%6N" # Same format in the base class, but without the space at the end.
    end

    def call(severity, time, progname, msg, context_hash: nil, tags_array: nil, parsed_tags_hash: nil)
      log_entry = {
        pid: Process.pid,
        severity: severity,
        timestamp: format_datetime(time),
        progname: progname,
        message: msg2str(msg)
      }

      log_entry[:context] = context_hash unless context_hash.nil? || context_hash.empty?
      log_entry[:tags] = tags_array unless tags_array.nil? || tags_array.empty?
      log_entry[:parsed_tags] = parsed_tags_hash unless parsed_tags_hash.nil? || parsed_tags_hash.empty?

      EnhancedStructuredLoggingRails.dump_json(log_entry) << "\n"
    end
  end
end
