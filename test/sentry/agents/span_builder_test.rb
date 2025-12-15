# frozen_string_literal: true

require "test_helper"

class Sentry::Agents::SpanBuilderTest < Minitest::Test
  include SentryTestHelpers

  def setup
    Sentry::Agents.reset_configuration!
  end

  def teardown
    teardown_sentry
  end

  def test_operations_constant_has_all_span_types
    assert_equal "gen_ai.invoke_agent", Sentry::Agents::SpanBuilder::OPERATIONS[:invoke_agent]
    assert_equal "gen_ai.chat", Sentry::Agents::SpanBuilder::OPERATIONS[:chat]
    assert_equal "gen_ai.execute_tool", Sentry::Agents::SpanBuilder::OPERATIONS[:execute_tool]
    assert_equal "gen_ai.handoff", Sentry::Agents::SpanBuilder::OPERATIONS[:handoff]
  end

  def test_sentry_available_returns_falsy_when_sentry_not_initialized
    refute Sentry::Agents::SpanBuilder.sentry_available?
  end

  def test_sentry_available_returns_falsy_when_no_span_exists
    Sentry.init
    # No span set on scope
    refute Sentry::Agents::SpanBuilder.sentry_available?
  end

  def test_sentry_available_returns_truthy_when_span_exists
    setup_sentry_with_span

    assert Sentry::Agents::SpanBuilder.sentry_available?
  end

  def test_build_yields_nil_when_sentry_not_available
    yielded_span = :not_called

    Sentry::Agents::SpanBuilder.build(
      operation: :chat,
      description: "test",
      attributes: {}
    ) do |span|
      yielded_span = span
    end

    assert_nil yielded_span
  end

  def test_build_returns_block_result_when_sentry_not_available
    result = Sentry::Agents::SpanBuilder.build(
      operation: :chat,
      description: "test",
      attributes: {}
    ) do |_span|
      "my result"
    end

    assert_equal "my result", result
  end

  def test_build_creates_child_span_when_sentry_available
    parent_span = setup_sentry_with_span

    Sentry::Agents::SpanBuilder.build(
      operation: :chat,
      description: "test chat",
      attributes: { "key" => "value" }
    ) do |span|
      refute_nil span
      assert_equal "gen_ai.chat", span.op
      assert_equal "test chat", span.description
    end

    assert_equal 1, parent_span.children.length
    child = parent_span.children.first
    assert child.finished
  end

  def test_build_sets_attributes_on_span
    parent_span = setup_sentry_with_span

    Sentry::Agents::SpanBuilder.build(
      operation: :invoke_agent,
      description: "agent test",
      attributes: {
        "gen_ai.agent.name" => "Emily",
        "gen_ai.request.model" => "claude-3-5-sonnet"
      }
    ) { |_span| :ok }

    child = parent_span.children.first
    assert_equal "Emily", child.data["gen_ai.agent.name"]
    assert_equal "claude-3-5-sonnet", child.data["gen_ai.request.model"]
  end

  def test_build_does_not_set_nil_attributes
    parent_span = setup_sentry_with_span

    Sentry::Agents::SpanBuilder.build(
      operation: :chat,
      description: "test",
      attributes: {
        "present" => "value",
        "nil_value" => nil
      }
    ) { |_span| :ok }

    child = parent_span.children.first
    assert_equal "value", child.data["present"]
    refute child.data.key?("nil_value")
  end

  def test_build_does_not_set_empty_string_attributes
    parent_span = setup_sentry_with_span

    Sentry::Agents::SpanBuilder.build(
      operation: :chat,
      description: "test",
      attributes: {
        "present" => "value",
        "empty" => ""
      }
    ) { |_span| :ok }

    child = parent_span.children.first
    assert_equal "value", child.data["present"]
    refute child.data.key?("empty")
  end

  def test_build_propagates_exceptions_from_block
    setup_sentry_with_span

    assert_raises StandardError do
      Sentry::Agents::SpanBuilder.build(
        operation: :chat,
        description: "test",
        attributes: {}
      ) do |_span|
        raise StandardError, "block error"
      end
    end
  end

  def test_build_finishes_span_even_when_block_raises
    parent_span = setup_sentry_with_span

    begin
      Sentry::Agents::SpanBuilder.build(
        operation: :chat,
        description: "test",
        attributes: {}
      ) do |_span|
        raise StandardError, "block error"
      end
    rescue StandardError
      # Expected
    end

    child = parent_span.children.first
    assert child.finished
  end

  def test_set_attributes_handles_nil_span
    # Should not raise
    Sentry::Agents::SpanBuilder.set_attributes(nil, { "key" => "value" })
  end
end
