# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "minitest/autorun"
require "sentry-agents"

# Mock Sentry module for testing without real Sentry dependency
module Sentry
  @initialized = false
  @current_scope = nil

  class << self
    attr_accessor :initialized, :current_scope

    def initialized?
      @initialized
    end

    def get_current_scope
      @current_scope
    end

    def init
      @initialized = true
      @current_scope = MockScope.new
    end

    def reset!
      @initialized = false
      @current_scope = nil
    end
  end

  class MockScope
    attr_accessor :span

    def initialize
      @span = nil
    end

    def get_span
      @span
    end
  end

  class MockSpan
    attr_reader :op, :description, :data, :children, :finished

    def initialize(op:, description:)
      @op = op
      @description = description
      @data = {}
      @children = []
      @finished = false
    end

    def set_data(key, value)
      @data[key] = value
    end

    def start_child(op:, description:)
      child = MockSpan.new(op: op, description: description)
      @children << child
      child
    end

    def finish
      @finished = true
    end
  end
end

module SentryTestHelpers
  def setup_sentry_with_span
    Sentry.init
    span = Sentry::MockSpan.new(op: "test.transaction", description: "Test Transaction")
    Sentry.current_scope.span = span
    span
  end

  def teardown_sentry
    Sentry.reset!
    Sentry::Agents.reset_configuration!
  end
end
