# frozen_string_literal: true

require_relative "agents/version"
require_relative "agents/configuration"
require_relative "agents/serializer"
require_relative "agents/span_builder"
require_relative "agents/instrumentation"

module Sentry
  # Sentry Gen AI instrumentation for AI/LLM agents
  #
  # @example Basic usage
  #   class MyAgent
  #     include Sentry::Agents::Instrumentation
  #
  #     def process(message)
  #       with_agent_span(agent_name: "MyAgent", model: "claude-3-5-sonnet") do
  #         # agent logic
  #       end
  #     end
  #   end
  #
  module Agents
    class << self
      # @return [Configuration] the current configuration
      # Thread-safe lazy initialization
      def configuration
        @mutex ||= Mutex.new
        @mutex.synchronize do
          @configuration ||= Configuration.new
        end
      end

      # Configure the gem
      #
      # @yield [Configuration] the configuration object
      # @return [void]
      #
      # @example
      #   Sentry::Agents.configure do |config|
      #     config.default_system = "anthropic"
      #     config.auto_instrument_ruby_llm = true
      #   end
      #
      def configure
        yield(configuration)
        apply_auto_instrumentation
      end

      # Reset configuration to defaults (mainly for testing)
      # Thread-safe reset
      # @return [void]
      def reset_configuration!
        @mutex ||= Mutex.new
        @mutex.synchronize do
          @configuration = Configuration.new
        end
      end

      private

      def apply_auto_instrumentation
        if configuration.auto_instrument_ruby_llm && defined?(RubyLLM)
          require_relative "agents/integrations/ruby_llm"
          Integrations::RubyLLM.install
        end

        if configuration.auto_instrument_langchainrb && defined?(Langchain)
          require_relative "agents/integrations/langchainrb"
          Integrations::LangChainRb.install
        end
      end
    end
  end
end
