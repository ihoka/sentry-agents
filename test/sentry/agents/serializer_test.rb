# frozen_string_literal: true

require "test_helper"

class Sentry::Agents::SerializerTest < Minitest::Test
  def setup
    Sentry::Agents.reset_configuration!
  end

  def teardown
    Sentry::Agents.reset_configuration!
  end

  def test_serialize_truncates_long_strings
    long_string = "a" * 2000

    result = Sentry::Agents::Serializer.serialize(long_string)

    # Default max_string_length is 1000, plus 3 for "..."
    assert_equal 1003, result.length
    assert result.end_with?("...")
  end

  def test_serialize_converts_hash_to_json
    hash = { key: "value", nested: { deep: true } }

    result = Sentry::Agents::Serializer.serialize(hash)

    assert_equal hash.to_json, result
  end

  def test_serialize_converts_array_to_json
    array = [1, 2, 3, { name: "test" }]

    result = Sentry::Agents::Serializer.serialize(array)

    assert_equal array.to_json, result
  end

  def test_serialize_converts_other_types_to_string
    result = Sentry::Agents::Serializer.serialize(12345)

    assert_equal "12345", result
  end

  def test_serialize_returns_nil_for_nil_input
    result = Sentry::Agents::Serializer.serialize(nil)

    assert_nil result
  end

  def test_serialize_respects_custom_max_length
    result = Sentry::Agents::Serializer.serialize("a" * 100, max_length: 50)

    assert_equal 53, result.length # 50 + "..."
    assert result.end_with?("...")
  end

  def test_serialize_does_not_truncate_short_strings
    short_string = "Hello, world!"

    result = Sentry::Agents::Serializer.serialize(short_string)

    assert_equal short_string, result
  end

  def test_truncate_returns_original_for_nil
    result = Sentry::Agents::Serializer.truncate(nil, 100)

    assert_nil result
  end

  def test_filter_returns_data_unchanged_when_no_filter_configured
    input = { "key" => "value", "another" => "data" }

    result = Sentry::Agents::Serializer.filter(input)

    assert_equal input, result
  end

  def test_filter_applies_data_filter_when_configured
    Sentry::Agents.configure do |config|
      config.data_filter = ->(data) { data.delete("secret"); data }
    end

    input = { "key" => "value", "secret" => "hidden" }
    result = Sentry::Agents::Serializer.filter(input)

    assert_equal({ "key" => "value" }, result)
  end

  def test_filter_does_not_modify_original_data
    Sentry::Agents.configure do |config|
      config.data_filter = ->(data) { data.delete("secret"); data }
    end

    input = { "key" => "value", "secret" => "hidden" }
    Sentry::Agents::Serializer.filter(input)

    # Original should still have secret (filter works on dup)
    assert_equal({ "key" => "value", "secret" => "hidden" }, input)
  end
end
