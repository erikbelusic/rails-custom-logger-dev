# frozen_string_literal: true

RSpec.describe EnhancedStructuredLoggingRails::TaggedAndContextualLogging do
  describe ".new" do
    it "wraps a logger and assigns a EnhancedStructuredLoggingRails::JsonFormatter formatter when logger has no formatter" do
      base_logger = ActiveSupport::Logger.new(StringIO.new)
      base_logger.formatter = nil
      logger = described_class.new(base_logger)

      expect(logger).to be_an_instance_of(ActiveSupport::Logger)
      expect(logger.formatter).to be_an_instance_of(EnhancedStructuredLoggingRails::JsonFormatter)
    end

    it "wraps a logger and does nothing when when logger has an EnhancedStructuredLoggingRails::JsonFormatter formatter" do
      base_logger = ActiveSupport::Logger.new(StringIO.new)
      base_logger.formatter = EnhancedStructuredLoggingRails::JsonFormatter.new
      logger = described_class.new(base_logger)

      expect(logger).to be_an_instance_of(ActiveSupport::Logger)
      expect(logger.formatter).to be_an_instance_of(EnhancedStructuredLoggingRails::JsonFormatter)
    end

    it "wraps a logger and does nothing when when logger has a subclass of EnhancedStructuredLoggingRails::JsonFormatter formatter" do
      class MyFormatter < EnhancedStructuredLoggingRails::JsonFormatter; end

      base_logger = ActiveSupport::Logger.new(StringIO.new)
      base_logger.formatter = MyFormatter.new
      logger = described_class.new(base_logger)

      expect(logger).to be_an_instance_of(ActiveSupport::Logger)
      expect(logger.formatter).to be_an_instance_of(MyFormatter)
    end

    it "raises an exception when logger has a formatter other than EnhancedStructuredLoggingRails::JsonFormatter or a subclass" do
      wrong_formatter_class = ActiveSupport::Logger::SimpleFormatter
      base_logger = ActiveSupport::Logger.new(StringIO.new)
      base_logger.formatter = wrong_formatter_class.new

      expect { described_class.new(base_logger) }.to raise_exception(EnhancedStructuredLoggingRails::UnsupportedFormatterError, "logger.formatter must be an instance of EnhancedStructuredLoggingRails::JsonFormatter, got: #{wrong_formatter_class}")
    end
  end
  describe "enhanced features" do
    # example copied from activesupport/test/tagged_logging_test.rb
    class MyLogger < ::ActiveSupport::Logger
      def flush(*)
        info "[FLUSHED]"
      end
    end

    before(:each) do
      @output = StringIO.new
      base_logger = MyLogger.new(@output)
      base_logger.formatter = EnhancedStructuredLoggingRails::JsonFormatter.new
      @logger = described_class.new(base_logger)
    end

    describe "tagging" do
      context "with block" do
        # example copied from activesupport/test/tagged_logging_test.rb
        it "tagged once" do
          @logger.tagged("BCX") { @logger.info "Funky time" }
          parsed_lines = parse_json_lines(@output.string)
          expect(parsed_lines[0]).to include(message: "Funky time", tags: contain_exactly("BCX"))
        end

        # example copied from activesupport/test/tagged_logging_test.rb
        it "tagged twice" do
          @logger.tagged("BCX") { @logger.tagged("Jason") { @logger.info "Funky time" } }
          parsed_lines = parse_json_lines(@output.string)
          expect(parsed_lines[0]).to include(message: "Funky time", tags: contain_exactly("BCX", "Jason"))
        end

        # example copied from activesupport/test/tagged_logging_test.rb
        it "tagged thrice at once" do
          @logger.tagged("BCX", "Jason", "New") { @logger.info "Funky time" }
          parsed_lines = parse_json_lines(@output.string)
          expect(parsed_lines[0]).to include(message: "Funky time", tags: contain_exactly("BCX", "Jason", "New"))
        end

        # example copied from activesupport/test/tagged_logging_test.rb
        it "tagged with an array" do
          @logger.tagged(%w(BCX Jason New)) { @logger.info "Funky time" }
          parsed_lines = parse_json_lines(@output.string)
          expect(parsed_lines[0]).to include(message: "Funky time", tags: contain_exactly("BCX", "Jason", "New"))
        end

        # example copied from activesupport/test/tagged_logging_test.rb
        it "tagged are flattened" do
          @logger.tagged("BCX", %w(Jason New)) { @logger.info "Funky time" }
          parsed_lines = parse_json_lines(@output.string)
          expect(parsed_lines[0]).to include(message: "Funky time", tags: contain_exactly("BCX", "Jason", "New"))
        end

        # example copied from activesupport/test/tagged_logging_test.rb
        it "push and pop tags directly" do
          expect(@logger.push_tags("A", ["B", "  ", ["C"]])).to eq %w(A B C)
          @logger.info "a"
          expect(@logger.pop_tags).to eq(%w(C))
          @logger.info "b"
          expect(@logger.pop_tags(1)).to eq(%w(B))
          @logger.info "c"
          expect(@logger.clear_tags!).to eq([])
          @logger.info "d"

          parsed_lines = parse_json_lines(@output.string)
          expect(parsed_lines[0]).to include(message: "a", tags: contain_exactly("A", "B", "C"))
          expect(parsed_lines[1]).to include(message: "b", tags: contain_exactly("A", "B"))
          expect(parsed_lines[2]).to include(message: "c", tags: contain_exactly("A"))
          expect(parsed_lines[3]).to include(message: "d")
          expect(parsed_lines[3]).not_to have_key(:tags)
        end

        # example copied from activesupport/test/tagged_logging_test.rb
        it "does not strip message content" do
          @logger.info "  Hello"
          parsed_lines = parse_json_lines(@output.string)
          expect(parsed_lines[0]).to include(message: "  Hello")
        end

        # example copied from activesupport/test/tagged_logging_test.rb
        it "provides access to the logger instance" do
          @logger.tagged("BCX") { |logger| logger.info "Funky time" }
          parsed_lines = parse_json_lines(@output.string)
          expect(parsed_lines[0]).to include(message: "Funky time", tags: contain_exactly("BCX"))
        end

        # example copied from activesupport/test/tagged_logging_test.rb
        it "tagged once with blank and nil" do
          @logger.tagged(nil, "", "New") { @logger.info "Funky time" }
          parsed_lines = parse_json_lines(@output.string)
          expect(parsed_lines[0]).to include(message: "Funky time", tags: contain_exactly("New"))
        end

        # example copied from activesupport/test/tagged_logging_test.rb
        it "keeps each tag in their own thread" do
          @logger.tagged("BCX") do
            Thread.new do
              @logger.info "Dull story"
              @logger.tagged("OMG") { @logger.info "Cool story" }
            end.join
            @logger.info "Funky time"
          end

          parsed_lines = parse_json_lines(@output.string)
          expect(parsed_lines[0]).to include(message: "Dull story")
          expect(parsed_lines[0]).not_to have_key(:tags)
          expect(parsed_lines[1]).to include(message: "Cool story", tags: contain_exactly("OMG"))
          expect(parsed_lines[2]).to include(message: "Funky time", tags: contain_exactly("BCX"))
        end

        # example copied from activesupport/test/tagged_logging_test.rb
        it "keeps each tag in their own thread even when pushed directly" do
          Thread.new do
            @logger.push_tags("OMG")
            @logger.info "Cool story"
          end.join
          @logger.info "Funky time"

          parsed_lines = parse_json_lines(@output.string)
          expect(parsed_lines[0]).to include(message: "Cool story", tags: contain_exactly("OMG"))
          expect(parsed_lines[1]).to include(message: "Funky time")
          expect(parsed_lines[1]).not_to have_key(:tags)
        end

        # example copied from activesupport/test/tagged_logging_test.rb
        it "keeps each tag in their own instance" do
          other_output = StringIO.new
          other_base_logger = MyLogger.new(other_output)
          other_base_logger.formatter = EnhancedStructuredLoggingRails::JsonFormatter.new
          other_logger = described_class.new(other_base_logger)

          @logger.tagged("OMG") do
            other_logger.tagged("BCX") do
              @logger.info "Cool story"
              other_logger.info "Funky time"
            end
          end

          parsed_lines = parse_json_lines(@output.string)
          expect(parsed_lines[0]).to include(message: "Cool story", tags: contain_exactly("OMG"))

          other_parsed_lines = parse_json_lines(other_output.string)
          expect(other_parsed_lines[0]).to include(message: "Funky time", tags: contain_exactly("BCX"))
        end

        # example copied from activesupport/test/tagged_logging_test.rb
        it "does not share the same formatter instance of the original logger" do
          other_logger = described_class.new(@logger)

          @logger.tagged("OMG") do
            other_logger.tagged("BCX") do
              @logger.info "Cool story"
              other_logger.info "Funky time"
            end
          end

          parsed_lines = parse_json_lines(@output.string)
          expect(parsed_lines[0]).to include(message: "Cool story", tags: contain_exactly("OMG"))
          expect(parsed_lines[1]).to include(message: "Funky time", tags: contain_exactly("BCX"))
        end

        # example copied from activesupport/test/tagged_logging_test.rb
        it "cleans up the taggings on flush" do
          @logger.tagged("BCX") do
            Thread.new do
              @logger.tagged("OMG") do
                @logger.flush
                @logger.info "Cool story"
              end
            end.join
          end

          parsed_lines = parse_json_lines(@output.string)
          expect(parsed_lines[0]).to include(message: "[FLUSHED]")
          expect(parsed_lines[0]).not_to have_key(:tags)
          expect(parsed_lines[1]).to include(message: "Cool story")
          expect(parsed_lines[1]).not_to have_key(:tags)
        end

        # example copied from activesupport/test/tagged_logging_test.rb
        it "mixed levels of tagging" do
          @logger.tagged("BCX") do
            @logger.tagged("Jason") { @logger.info "Funky time" }
            @logger.info "Junky time!"
          end

          parsed_lines = parse_json_lines(@output.string)
          expect(parsed_lines[0]).to include(message: "Funky time", tags: contain_exactly("BCX", "Jason"))
          expect(parsed_lines[1]).to include(message: "Junky time!", tags: contain_exactly("BCX"))
        end
      end
      context "without block"
    end
    describe "tag parsing" do
      context "with block" do
        it "does not parse when string does not contain equals sign" do
          @logger.tagged("BCX") { @logger.info "Funky time" }
          parsed_lines = parse_json_lines(@output.string)
          expect(parsed_lines[0]).to include(message: "Funky time")
          expect(parsed_lines[0]).not_to have_key(:parsed_tags)
        end

        it "parses basic key/value pair" do
          @logger.tagged("key=value") { @logger.info "Funky time" }
          parsed_lines = parse_json_lines(@output.string)
          expect(parsed_lines[0]).to include(message: "Funky time", parsed_tags: { key: "value" })
        end

        it "parses dot notated keys as nested objects" do
          @logger.tagged("parent.child=value") { @logger.info "Funky time" }
          parsed_lines = parse_json_lines(@output.string)
          expect(parsed_lines[0]).to include(message: "Funky time", parsed_tags: { parent: { child: "value" } })
        end

        it "parses deeply nested dot notated keys as nested objects" do
          @logger.tagged("a.b.c.d.e.f=value") { @logger.info "Funky time" }
          parsed_lines = parse_json_lines(@output.string)
          expect(parsed_lines[0]).to include(message: "Funky time", parsed_tags: { a: { b: { c: { d: { e: { f: "value" } } } } } })
        end

        it "parses the most recent (right most) tag when identical keys are used in same call" do
          @logger.tagged("key=value", "key=new value") { @logger.info "Funky time" }
          parsed_lines = parse_json_lines(@output.string)
          expect(parsed_lines[0]).to include(message: "Funky time", parsed_tags: { key: "new value" })
        end

        it "parses the most recent tag when identical keys are used in nested blocks" do
          @logger.tagged("key=value") do
            @logger.tagged("key=new value") do
              @logger.info "Funky time"
            end
          end
          parsed_lines = parse_json_lines(@output.string)
          expect(parsed_lines[0]).to include(message: "Funky time", parsed_tags: { key: "new value" })
        end

        it "mixed levels of dot notated tags" do
          @logger.tagged("http.request.id=123", "http.request.user_id=1") do
            @logger.info "starting"
            @logger.tagged("klass=SomeClass") { @logger.info "doing a thing" }
            @logger.tagged("http.response.code=200", "http.response.duration=55") { @logger.info "done" }
          end

          parsed_lines = parse_json_lines(@output.string)
          expect(parsed_lines[0]).to include(message: "starting", parsed_tags: { http: { request: { id: "123", user_id: "1" } } })
          expect(parsed_lines[1]).to include(message: "doing a thing", parsed_tags: { http: { request: { id: "123", user_id: "1" } }, klass: "SomeClass" })
          expect(parsed_lines[2]).to include(message: "done", parsed_tags: { http: { request: { id: "123", user_id: "1" }, response: { code: "200", duration: "55" } } })
        end

        it "parses the most recent dot notated tag when identical keys are used in nested blocks (overwrites string with hash)" do
          @logger.tagged("a.b=value") do
            @logger.info "Boom"
            @logger.tagged("a.b.c=new value") do
              @logger.info "Funky time"
            end
          end

          parsed_lines = parse_json_lines(@output.string)
          expect(parsed_lines[0]).to include(message: "Boom", parsed_tags: { a: { b: "value" } })
          expect(parsed_lines[1]).to include(message: "Funky time", parsed_tags: { a: { b: { c: "new value" } } })
        end

        it "parses the most recent dot notated tag when identical keys are used in nested blocks (overwrites hash with string)" do
          @logger.tagged("a.b.c=new value") do
            @logger.info "Boom"
            @logger.tagged("a.b=value") do
              @logger.info "Funky time"
            end
          end

          parsed_lines = parse_json_lines(@output.string)
          expect(parsed_lines[0]).to include(message: "Boom", parsed_tags: { a: { b: { c: "new value" } } })
          expect(parsed_lines[1]).to include(message: "Funky time", parsed_tags: { a: { b: "value" } })
        end
      end
    end
    describe "adding context" do
      context "with block" do
        # it "works" do
        #   @logger.with_context(some_key: "some value") { @logger.info "Funky time" }
        #   parsed_lines = parse_json_lines(@output.string)
        #   expect(parsed_lines[0]).to include(message: "Funky time", context: { some_key: "some value" })
        # end
      end
      context "without block"
    end
  end

  # Parses a multiple lines of JSON objects string into an array of hashes.
  #
  # @param string [String] The string to be parsed.
  # @param deep_symbolize_keys [Boolean] Whether to recursively symbolize keys in the resulting hashes.
  #                                      Defaults to true.
  # @return [Array<Hash>] An array of hashes, where each element represents a parsed JSON object.
  #
  # @example
  #   input_string = '{"name": "John", "age": 30}\n{"name": "Alice", "age": 25}'
  #   parsed_hashes = parse_json_lines(input_string)
  #   # => [{:name=>"John", :age=>30}, {:name=>"Alice", :age=>25}]
  #
  # @example
  #   input_string = '{"name": "John", "age": 30}\n{"name": "Alice", "age": 25}'
  #   parsed_hashes = parse_json_lines(input_string, deep_symbolize_keys: false)
  #   # => [{"name"=>"John", "age"=>30}, {"name"=>"Alice", "age"=>25}]
  def parse_json_lines(string, deep_symbolize_keys: true)
    lines = string.split("\n")
    lines.map do |line|
      hash = JSON.parse(line)
      deep_symbolize_keys ? hash.deep_symbolize_keys : hash
    end
  end
end
