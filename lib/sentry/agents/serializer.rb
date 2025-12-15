# frozen_string_literal: true

require "json"

module Sentry
  module Agents
    # Handles data serialization for span attributes
    #
    # Provides utilities for converting various data types to strings
    # suitable for Sentry span attributes, with truncation and filtering.
    #
    class Serializer
      class << self
        # Serialize a value for use in span attributes
        #
        # @param value [Object] the value to serialize
        # @param max_length [Integer, nil] maximum length for the result
        # @return [String, nil] the serialized value
        #
        # @example
        #   Serializer.serialize({ key: "value" })
        #   # => '{"key":"value"}'
        #
        #   Serializer.serialize("a" * 2000, max_length: 100)
        #   # => "aaa...aaa..." (truncated to 100 chars)
        #
        def serialize(value, max_length: nil)
          max_length ||= Sentry::Agents.configuration.max_string_length

          result = case value
          when String
            value
          when Hash, Array
            value.to_json
          when NilClass
            return nil
          else
            value.to_s
          end

          truncate(result, max_length)
        end

        # Truncate a string to the specified maximum length
        #
        # @param str [String] the string to truncate
        # @param max_length [Integer] maximum length
        # @return [String] the truncated string
        #
        def truncate(str, max_length)
          return str if str.nil? || str.length <= max_length

          "#{str[0...max_length]}..."
        end

        # Apply custom data filter if configured
        #
        # @param data [Hash] the data to filter
        # @return [Hash] the filtered data
        #
        def filter(data)
          filter_proc = Sentry::Agents.configuration.data_filter
          return data unless filter_proc

          filter_proc.call(data.dup)
        end
      end
    end
  end
end
