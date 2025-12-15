# frozen_string_literal: true

module Sentry
  module Agents
    # Configuration class for sentry-agents gem
    #
    # @example Basic configuration
    #   Sentry::Agents.configure do |config|
    #     config.default_system = "anthropic"
    #     config.max_string_length = 2000
    #   end
    #
    class Configuration
      # Default LLM provider system name (e.g., "anthropic", "openai", "cohere")
      # @return [String]
      attr_accessor :default_system

      # Enable auto-instrumentation for RubyLLM gem
      # @return [Boolean]
      attr_accessor :auto_instrument_ruby_llm

      # Enable auto-instrumentation for LangChain.rb gem
      # @return [Boolean]
      attr_accessor :auto_instrument_langchainrb

      # Maximum length for serialized strings in span attributes
      # @return [Integer]
      attr_accessor :max_string_length

      # Enable debug logging
      # @return [Boolean]
      attr_accessor :debug

      # Custom data filter hook for sanitizing span data
      # @return [Proc, nil]
      attr_accessor :data_filter

      def initialize
        @default_system = "anthropic"
        @auto_instrument_ruby_llm = false
        @auto_instrument_langchainrb = false
        @max_string_length = 1000
        @debug = false
        @data_filter = nil
      end
    end
  end
end
