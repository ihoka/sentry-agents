# frozen_string_literal: true

# Example: Multi-Provider Usage with sentry-agents gem
#
# This example shows how to use sentry-agents with multiple LLM providers,
# overriding the default system on a per-span basis.

require "sentry-ruby"
require "sentry-agents"

# Configure Sentry
Sentry.init do |config|
  config.dsn = ENV.fetch("SENTRY_DSN", nil)
  config.traces_sample_rate = 1.0
end

# Configure sentry-agents with default provider
Sentry::Agents.configure do |config|
  config.default_system = "anthropic" # Default provider
  config.max_string_length = 1000
end

# Example: Router agent that delegates to specialized agents
class RouterAgent
  include Sentry::Agents::Instrumentation

  def initialize(anthropic_client:, openai_client:, gemini_client:)
    @anthropic_client = anthropic_client
    @openai_client = openai_client
    @gemini_client = gemini_client
  end

  def route_request(user_message, provider: nil)
    with_agent_span(agent_name: "RouterAgent", model: determine_model(provider)) do
      case provider
      when :openai
        call_openai(user_message)
      when :gemini
        call_gemini(user_message)
      else
        call_anthropic(user_message) # Default
      end
    end
  end

  private

  def determine_model(provider)
    case provider
    when :openai then "gpt-4"
    when :gemini then "gemini-pro"
    else "claude-3-5-sonnet"
    end
  end

  def call_anthropic(_message)
    # Uses default system from config ("anthropic")
    with_chat_span(model: "claude-3-5-sonnet") do
      # @anthropic_client.messages.create(...)
      mock_response("Hello from Claude!")
    end
  end

  def call_openai(_message)
    # Override system for OpenAI
    with_chat_span(model: "gpt-4", system: "openai") do
      # @openai_client.chat.completions.create(...)
      mock_response("Hello from GPT-4!")
    end
  end

  def call_gemini(_message)
    # Override system for Google Gemini
    with_chat_span(model: "gemini-pro", system: "google-gemini") do
      # @gemini_client.generate_content(...)
      mock_response("Hello from Gemini!")
    end
  end

  def mock_response(content)
    MockResponse.new(content: content, input_tokens: 100, output_tokens: 20)
  end
end

# Mock response class
class MockResponse
  attr_reader :content, :input_tokens, :output_tokens

  def initialize(content:, input_tokens:, output_tokens:)
    @content = content
    @input_tokens = input_tokens
    @output_tokens = output_tokens
  end
end

# Usage example
if __FILE__ == $PROGRAM_NAME
  puts "sentry-agents Multi-Provider Example"
  puts "====================================="
  puts

  router = RouterAgent.new(
    anthropic_client: nil,
    openai_client: nil,
    gemini_client: nil
  )

  puts "Calling default provider (Anthropic)..."
  result = router.route_request("Hello!", provider: nil)
  puts "Response: #{result.content}"
  puts

  puts "Calling OpenAI..."
  result = router.route_request("Hello!", provider: :openai)
  puts "Response: #{result.content}"
  puts

  puts "Calling Google Gemini..."
  result = router.route_request("Hello!", provider: :gemini)
  puts "Response: #{result.content}"
  puts

  puts "Each call would create spans with the appropriate 'gen_ai.system' attribute:"
  puts "  - Anthropic: gen_ai.system = 'anthropic'"
  puts "  - OpenAI:    gen_ai.system = 'openai'"
  puts "  - Gemini:    gen_ai.system = 'google-gemini'"
end
