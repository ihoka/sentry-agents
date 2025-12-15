# frozen_string_literal: true

require "test_helper"

class Sentry::Agents::InstrumentationTest < Minitest::Test
  include SentryTestHelpers

  class TestClass
    include Sentry::Agents::Instrumentation

    def agent_name
      "TestAgent"
    end

    def model
      "claude-3-5-sonnet"
    end
  end

  # Mock response object that behaves like RubyLLM response
  class MockResponse
    attr_reader :content, :input_tokens, :output_tokens

    def initialize(content: "test response", input_tokens: 100, output_tokens: 50)
      @content = content
      @input_tokens = input_tokens
      @output_tokens = output_tokens
    end
  end

  def setup
    @test_obj = TestClass.new
    Sentry::Agents.reset_configuration!
  end

  def teardown
    teardown_sentry
  end

  # === with_agent_span tests ===

  def test_with_agent_span_yields_block_and_returns_result
    result = @test_obj.with_agent_span(agent_name: "Emily", model: "claude-3-5-sonnet") do
      "agent_result"
    end

    assert_equal "agent_result", result
  end

  def test_with_agent_span_passes_through_exceptions
    assert_raises StandardError do
      @test_obj.with_agent_span(agent_name: "Emily", model: "claude-3-5-sonnet") do
        raise StandardError, "test error"
      end
    end
  end

  def test_with_agent_span_creates_span_when_sentry_available
    parent_span = setup_sentry_with_span

    @test_obj.with_agent_span(agent_name: "Emily", model: "claude-3-5-sonnet") do
      "result"
    end

    assert_equal 1, parent_span.children.length
    child_span = parent_span.children.first
    assert_equal "gen_ai.invoke_agent", child_span.op
    assert_equal "invoke_agent Emily", child_span.description
    assert_equal "Emily", child_span.data["gen_ai.agent.name"]
    assert_equal "claude-3-5-sonnet", child_span.data["gen_ai.request.model"]
    assert child_span.finished
  end

  def test_with_agent_span_captures_token_usage
    parent_span = setup_sentry_with_span
    response = MockResponse.new(input_tokens: 150, output_tokens: 75)

    @test_obj.with_agent_span(agent_name: "Emily", model: "claude-3-5-sonnet") do
      response
    end

    child_span = parent_span.children.first
    assert_equal 150, child_span.data["gen_ai.usage.input_tokens"]
    assert_equal 75, child_span.data["gen_ai.usage.output_tokens"]
  end

  # === with_chat_span tests ===

  def test_with_chat_span_yields_block_and_returns_result
    response = MockResponse.new

    result = @test_obj.with_chat_span(model: "claude-3-5-sonnet") do
      response
    end

    assert_equal response, result
  end

  def test_with_chat_span_passes_through_exceptions
    assert_raises StandardError do
      @test_obj.with_chat_span(model: "claude-3-5-sonnet") do
        raise StandardError, "LLM error"
      end
    end
  end

  def test_with_chat_span_accepts_optional_messages_parameter
    messages = [{ role: "user", content: "Hello" }]

    result = @test_obj.with_chat_span(model: "claude-3-5-sonnet", messages: messages) do
      MockResponse.new
    end

    assert_instance_of MockResponse, result
  end

  def test_with_chat_span_accepts_system_override
    result = @test_obj.with_chat_span(model: "gpt-4", system: "openai") do
      MockResponse.new
    end

    assert_instance_of MockResponse, result
  end

  def test_with_chat_span_creates_span_when_sentry_available
    parent_span = setup_sentry_with_span

    @test_obj.with_chat_span(model: "claude-3-5-sonnet") do
      MockResponse.new
    end

    child_span = parent_span.children.first
    assert_equal "gen_ai.chat", child_span.op
    assert_equal "chat claude-3-5-sonnet", child_span.description
  end

  def test_with_chat_span_captures_response_text
    parent_span = setup_sentry_with_span

    @test_obj.with_chat_span(model: "claude-3-5-sonnet") do
      MockResponse.new(content: "Hello, world!")
    end

    child_span = parent_span.children.first
    assert_equal '["Hello, world!"]', child_span.data["gen_ai.response.text"]
  end

  # === with_tool_span tests ===

  def test_with_tool_span_yields_block_and_returns_result
    result = @test_obj.with_tool_span(tool_name: "ExtractionTool") do
      { extracted: "data" }
    end

    assert_equal({ extracted: "data" }, result)
  end

  def test_with_tool_span_accepts_tool_input_parameter
    tool_input = { query: "New York" }

    result = @test_obj.with_tool_span(tool_name: "CitySearchTool", tool_input: tool_input) do
      '{"found": true}'
    end

    assert_equal '{"found": true}', result
  end

  def test_with_tool_span_passes_through_exceptions
    assert_raises StandardError do
      @test_obj.with_tool_span(tool_name: "FailingTool") do
        raise StandardError, "tool error"
      end
    end
  end

  def test_with_tool_span_creates_span_when_sentry_available
    parent_span = setup_sentry_with_span

    @test_obj.with_tool_span(tool_name: "SearchTool", tool_input: { q: "test" }) do
      "result"
    end

    child_span = parent_span.children.first
    assert_equal "gen_ai.execute_tool", child_span.op
    assert_equal "execute_tool SearchTool", child_span.description
    assert_equal "SearchTool", child_span.data["gen_ai.tool.name"]
  end

  # === with_handoff_span tests ===

  def test_with_handoff_span_yields_block_and_returns_result
    result = @test_obj.with_handoff_span(from_stage: "greeting", to_stage: "qualification") do
      :stage_updated
    end

    assert_equal :stage_updated, result
  end

  def test_with_handoff_span_passes_through_exceptions
    assert_raises StandardError do
      @test_obj.with_handoff_span(from_stage: "qualification", to_stage: "routing") do
        raise StandardError, "transition error"
      end
    end
  end

  def test_with_handoff_span_creates_span_when_sentry_available
    parent_span = setup_sentry_with_span

    @test_obj.with_handoff_span(from_stage: "greeting", to_stage: "qualification") do
      :ok
    end

    child_span = parent_span.children.first
    assert_equal "gen_ai.handoff", child_span.op
    assert_equal "handoff from greeting to qualification", child_span.description
    assert_equal "greeting", child_span.data["gen_ai.handoff.from"]
    assert_equal "qualification", child_span.data["gen_ai.handoff.to"]
  end

  # === Graceful degradation tests ===

  def test_methods_work_when_sentry_is_not_available
    result = @test_obj.with_agent_span(agent_name: "Emily", model: "test") do
      "still works"
    end

    assert_equal "still works", result
  end

  def test_all_span_methods_work_without_active_sentry_transaction
    agent_result = @test_obj.with_agent_span(agent_name: "Test", model: "test") { :agent }
    chat_result = @test_obj.with_chat_span(model: "test") { :chat }
    tool_result = @test_obj.with_tool_span(tool_name: "test") { :tool }
    handoff_result = @test_obj.with_handoff_span(from_stage: "a", to_stage: "b") { :handoff }

    assert_equal :agent, agent_result
    assert_equal :chat, chat_result
    assert_equal :tool, tool_result
    assert_equal :handoff, handoff_result
  end
end
