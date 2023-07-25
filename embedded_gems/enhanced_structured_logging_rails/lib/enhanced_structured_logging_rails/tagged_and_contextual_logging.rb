# frozen_string_literal: true

module EnhancedStructuredLoggingRails
  # The following implementation is based on ActiveSupport::TaggedLogging
  module TaggedAndContextualLogging
    module Formatter # :nodoc:
      # This method is invoked when a log event occurs.
      def call(severity, timestamp, progname, msg)
        super(severity, timestamp, progname, msg, tags_array: tag_stack.tags, parsed_tags_hash: tag_stack.current_parsed_tags)
      end

      def tagged(*tags)
        pushed_count = tag_stack.push_tags(tags).size
        yield self
      ensure
        pop_tags(pushed_count)
      end

      def push_tags(*tags)
        tag_stack.push_tags(tags)
      end

      def pop_tags(count = 1)
        tag_stack.pop_tags(count)
      end

      def clear_tags!
        tag_stack.clear
      end

      def tag_stack
        # We use our object ID here to avoid conflicting with other instances
        @tags_thread_key ||= "enhanced_structured_logging_rails_tags:#{object_id}"
        ActiveSupport::IsolatedExecutionState[@tags_thread_key] ||= TagStack.new
      end

      def current_tags
        tag_stack.tags
      end

      # def with_context(additional_context_hash)
      #   context_stack.push_additional_context(additional_context_hash)
      #   yield self
      # ensure
      #   context_stack.pop_context
      # end
      #
      # def context_stack
      #   # We use our object ID here to avoid conflicting with other instances
      #   @context_thread_key ||= "enhanced_structured_logging_rails_context:#{object_id}"
      #   ActiveSupport::IsolatedExecutionState[@context_thread_key] ||= ContextStack.new
      # end
    end

    class TagStack # :nodoc:
      attr_reader :tags

      def initialize
        @tags = []
        @parsed_tags = []
      end

      def current_parsed_tags
        @parsed_tags.last
      end

      def push_tags(tags)
        tags.flatten!
        tags.reject!(&:blank?)
        @tags.concat(tags)
        push_parsed_tags(tags)
        tags
      end

      def pop_tags(count)
        @parsed_tags.pop(count)
        @tags.pop(count)
      end

      def clear
        @parsed_tags.clear
        @tags.clear
      end

      private

      def push_parsed_tags(sanitized_tags)
        new_parsed_tags = current_parsed_tags.nil? ? {} : current_parsed_tags.dup
        sanitized_tags.each do |tag|
          next unless tag.include?("=")

          key, value = tag.split("=", 2)
          keys = key.split(".").map(&:to_sym)
          add_to_hash_nested(new_parsed_tags, keys, value)
        end
        @parsed_tags << new_parsed_tags
      end

      def add_to_hash_nested(hash, keys, value)
        key = keys.shift
        if keys.length == 0
          hash[key] = value
        else
          # if this was previously a string, it will be overwritten
          hash[key] = {} unless hash[key].is_a?(Hash)
          add_to_hash_nested(hash[key], keys, value)
        end
      end
    end

    # class ContextStack # :nodoc:
    #   def initialize
    #     @contexts = []
    #   end
    #
    #   def current
    #     @contexts.last
    #   end
    #
    #   def push_additional_context(additional_context_hash)
    #     new_context = (current || {}).merge(additional_context_hash)
    #     @contexts << new_context
    #     new_context
    #   end
    #
    #   def pop_context
    #     @contexts.pop(1)
    #   end
    #
    #   def clear
    #     @contexts.clear
    #   end
    # end

    def self.new(logger)
      logger = logger.clone

      if logger.formatter.nil?
        # Ensure we set a default json formatter
        logger.formatter = ::EnhancedStructuredLoggingRails::JsonFormatter.new
      elsif logger.formatter.is_a?(::EnhancedStructuredLoggingRails::JsonFormatter)
        logger.formatter = logger.formatter.clone
      else
        raise UnsupportedFormatterError, "logger.formatter must be an instance of EnhancedStructuredLoggingRails::JsonFormatter, got: #{logger.formatter.class}"
      end

      logger.formatter.extend Formatter
      logger.extend(self)
    end

    delegate :push_tags, :pop_tags, :clear_tags!, to: :formatter

    def tagged(*tags)
      # if block_given?
        formatter.tagged(*tags) { yield self }
      # else
      #   logger = ActiveSupport::TaggedLogging.new(self)
      #   logger.formatter.extend LocalTagStorage
      #   logger.push_tags(*formatter.current_tags, *tags)
      #   logger
      # end
    end

    # def with_context(additional_context_hash)
    #   formatter.with_context(additional_context_hash) { yield self }
    # end

    def flush
      clear_tags!
      super if defined?(super)
    end
  end
end
