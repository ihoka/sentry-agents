# frozen_string_literal: true

# Example: Basic Usage with sentry-agents gem
#
# This example shows how to manually instrument an AI agent with Sentry Gen AI spans.

require "sentry-ruby"
require "sentry-agents"

# Configure Sentry (required for tracing to work)
Sentry.init do |config|
  config.dsn = ENV.fetch("SENTRY_DSN", nil)
  config.traces_sample_rate = 1.0
end

# Configure sentry-agents
Sentry::Agents.configure do |config|
  config.default_system = "anthropic"
  config.max_string_length = 1000
end

# Example AI Agent class
class CustomerServiceAgent
  include Sentry::Agents::Instrumentation

  def initialize(llm_client)
    @llm_client = llm_client
  end

  def process_request(user_message)
    # Wrap the entire agent invocation
    with_agent_span(agent_name: "CustomerServiceAgent", model: "claude-3-5-sonnet") do
      # First, get the AI response
      response = get_llm_response(user_message)

      # If the AI requested a tool call, execute it
      if response[:tool_use]
        execute_tool(response[:tool_use])
        # Continue conversation with tool result...
      end

      # Track stage transitions
      with_handoff_span(from_stage: "processing", to_stage: "complete") do
        finalize_response(response)
      end

      response
    end
  end

  private

  def get_llm_response(message)
    # Wrap the LLM API call
    with_chat_span(model: "claude-3-5-sonnet", messages: build_messages(message)) do
      # In real code, this would call your LLM client
      # response = @llm_client.messages.create(...)
      # The response should have input_tokens, output_tokens, and content methods/attributes

      # Mock response for example
      MockResponse.new(
        content: "Hello! How can I help you today?",
        input_tokens: 150,
        output_tokens: 25
      )
    end
  end

  def execute_tool(tool_use)
    # Wrap tool execution
    with_tool_span(tool_name: tool_use[:name], tool_input: tool_use[:input]) do
      # Execute the tool
      case tool_use[:name]
      when "lookup_order"
        lookup_order(tool_use[:input][:order_id])
      when "check_inventory"
        check_inventory(tool_use[:input][:product_id])
      else
        { error: "Unknown tool" }
      end
    end
  end

  def build_messages(message)
    [{ role: "user", content: message }]
  end

  def finalize_response(response)
    # Finalize and return the response
    response
  end

  def lookup_order(order_id)
    { order_id: order_id, status: "shipped" }
  end

  def check_inventory(product_id)
    { product_id: product_id, in_stock: true, quantity: 42 }
  end
end

# Mock response class for the example
class MockResponse
  attr_reader :content, :input_tokens, :output_tokens

  def initialize(content:, input_tokens:, output_tokens:)
    @content = content
    @input_tokens = input_tokens
    @output_tokens = output_tokens
  end
end

# Usage example (would be run within a Sentry transaction in production)
if __FILE__ == $PROGRAM_NAME
  puts "sentry-agents Basic Usage Example"
  puts "================================="
  puts

  # In production, this would be inside a Sentry transaction
  # Sentry.with_child_span(op: "http.server", description: "POST /chat") do |span|
  #   agent = CustomerServiceAgent.new(llm_client)
  #   agent.process_request("What's the status of my order #12345?")
  # end

  agent = CustomerServiceAgent.new(nil)

  puts "Processing request without Sentry transaction (graceful degradation)..."
  result = agent.process_request("What's the status of my order #12345?")
  puts "Response: #{result.content}"
  puts
  puts "Note: Without an active Sentry transaction, spans are not created,"
  puts "but the code executes normally. This is the graceful degradation feature."
end
