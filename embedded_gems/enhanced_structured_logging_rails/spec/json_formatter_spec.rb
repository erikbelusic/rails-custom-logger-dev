# frozen_string_literal: true

RSpec.describe EnhancedStructuredLoggingRails::JsonFormatter do
  describe "#call" do
    before(:each) do
      @severity = "INFO"
      @time = Time.utc(2023, 1, 2, 3, 45, 6.789123)
      @expected_time_string = "2023-01-02T03:45:06.789123"
      @progname = "ruby"
      @msg = "This is a test"
      @pid = 9876
      allow(Process).to receive(:pid).and_return(@pid)

      @formatter = described_class.new
    end

    it "returns a json string with proper keys and values when called with the base ruby formatter's interface" do
      result = @formatter.call(@severity, @time, @progname, @msg)

      expect(result).to end_with("\n")
      parsed_json_result = JSON.parse(result).deep_symbolize_keys
      expect(parsed_json_result).to eq({
                                         pid: @pid,
                                         severity: @severity,
                                         timestamp: @expected_time_string,
                                         progname: @progname,
                                         message: @msg
                                       })
    end

    it "returns a json string with proper keys and values when called with extra arguments" do
      context_hash = {
        key1: "value1",
        key2: {
          key3: "value2"
        }
      }
      tags_array = %w[tag1 tag2 key=val]
      parsed_tags_hash = {
        key: "val",
      }
      result = @formatter.call(@severity, @time, @progname, @msg, context_hash: context_hash, tags_array: tags_array, parsed_tags_hash: parsed_tags_hash)

      expect(result).to end_with("\n")
      parsed_json_result = JSON.parse(result).deep_symbolize_keys
      expect(parsed_json_result).to eq({
                                         pid: @pid,
                                         severity: @severity,
                                         timestamp: @expected_time_string,
                                         progname: @progname,
                                         message: @msg,
                                         context: context_hash,
                                         tags: tags_array,
                                         parsed_tags: parsed_tags_hash,
                                       })
    end
  end
end
