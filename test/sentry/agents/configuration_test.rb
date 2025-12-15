# frozen_string_literal: true

require "test_helper"

class Sentry::Agents::ConfigurationTest < Minitest::Test
  def setup
    Sentry::Agents.reset_configuration!
  end

  def teardown
    Sentry::Agents.reset_configuration!
  end

  def test_default_configuration_values
    config = Sentry::Agents.configuration

    assert_equal "anthropic", config.default_system
    assert_equal false, config.auto_instrument_ruby_llm
    assert_equal false, config.auto_instrument_langchainrb
    assert_equal 1000, config.max_string_length
    assert_equal false, config.debug
    assert_nil config.data_filter
  end

  def test_configure_block_yields_configuration
    Sentry::Agents.configure do |config|
      config.default_system = "openai"
      config.max_string_length = 2000
    end

    assert_equal "openai", Sentry::Agents.configuration.default_system
    assert_equal 2000, Sentry::Agents.configuration.max_string_length
  end

  def test_configure_supports_data_filter_proc
    filter = ->(data) { data.delete("sensitive_key"); data }

    Sentry::Agents.configure do |config|
      config.data_filter = filter
    end

    assert_equal filter, Sentry::Agents.configuration.data_filter
  end

  def test_configure_supports_debug_mode
    Sentry::Agents.configure do |config|
      config.debug = true
    end

    assert_equal true, Sentry::Agents.configuration.debug
  end

  def test_configure_supports_auto_instrument_ruby_llm
    Sentry::Agents.configure do |config|
      config.auto_instrument_ruby_llm = true
    end

    assert_equal true, Sentry::Agents.configuration.auto_instrument_ruby_llm
  end

  def test_configure_supports_auto_instrument_langchainrb
    Sentry::Agents.configure do |config|
      config.auto_instrument_langchainrb = true
    end

    assert_equal true, Sentry::Agents.configuration.auto_instrument_langchainrb
  end

  def test_reset_configuration_restores_defaults
    Sentry::Agents.configure do |config|
      config.default_system = "cohere"
      config.max_string_length = 500
      config.debug = true
    end

    Sentry::Agents.reset_configuration!

    assert_equal "anthropic", Sentry::Agents.configuration.default_system
    assert_equal 1000, Sentry::Agents.configuration.max_string_length
    assert_equal false, Sentry::Agents.configuration.debug
  end

  def test_configuration_is_thread_safe
    threads = 10.times.map do |i|
      Thread.new do
        Sentry::Agents.configure do |config|
          config.max_string_length = 1000 + i
        end
        Sentry::Agents.configuration.max_string_length
      end
    end

    results = threads.map(&:value)

    # All threads should complete without errors
    assert_equal 10, results.length
    results.each { |r| assert_kind_of Integer, r }
  end
end
