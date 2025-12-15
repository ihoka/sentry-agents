# Sentry Agents

Sentry Gen AI instrumentation for AI/LLM agents in Ruby applications.

Provides [Sentry's AI Agents monitoring](https://docs.sentry.io/platforms/python/tracing/instrumentation/custom-instrumentation/ai-agents-module/) capabilities for Ruby, supporting multiple LLM providers (Anthropic, OpenAI, Cohere, Google Gemini, etc.).

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'sentry-agents'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install sentry-agents
```

## Requirements

- Ruby >= 3.1.0
- sentry-ruby >= 5.0.0

## Configuration

```ruby
Sentry::Agents.configure do |config|
  # Default LLM provider (default: "anthropic")
  config.default_system = "anthropic"

  # Maximum string length for serialized data (default: 1000)
  config.max_string_length = 1000

  # Enable debug logging (default: false)
  config.debug = false

  # Custom data filtering (optional)
  config.data_filter = ->(data) do
    # Remove sensitive keys in production
    data.delete("gen_ai.request.messages") if ENV["SENTRY_SKIP_MESSAGES"]
    data
  end
end
```

## Usage

### Manual Instrumentation

Include the `Sentry::Agents::Instrumentation` module in any class:

```ruby
class MyAgent
  include Sentry::Agents::Instrumentation

  def process_request(user_message)
    with_agent_span(agent_name: "MyAgent", model: "claude-3-5-sonnet") do
      # Get LLM response
      response = with_chat_span(model: "claude-3-5-sonnet") do
        client.messages.create(
          model: "claude-3-5-sonnet-20241022",
          messages: [{ role: "user", content: user_message }]
        )
      end

      # Execute tool if needed
      if response.stop_reason == "tool_use"
        with_tool_span(
          tool_name: "search",
          tool_input: { query: response.tool_input["query"] }
        ) do
          search_service.search(response.tool_input["query"])
        end
      end

      # Track stage transition
      with_handoff_span(from_stage: "processing", to_stage: "complete") do
        update_status!(:complete)
      end

      response
    end
  end
end
```

### Custom Provider Override

Override the default provider on a per-span basis:

```ruby
class OpenAIAgent
  include Sentry::Agents::Instrumentation

  def process(message)
    with_chat_span(model: "gpt-4", system: "openai") do
      openai_client.chat(model: "gpt-4", messages: [message])
    end
  end
end
```

## Span Types

### Agent Invocation (`gen_ai.invoke_agent`)

Wraps the overall agent execution lifecycle.

```ruby
with_agent_span(agent_name: "Emily", model: "claude-3-5-sonnet") do
  # Full agent conversation logic
end
```

### Chat Completion (`gen_ai.chat`)

Wraps individual LLM API calls. Automatically captures:
- Token usage (input/output tokens)
- Response text

```ruby
with_chat_span(model: "claude-3-5-sonnet", messages: conversation_history) do
  llm_client.chat(messages)
end
```

### Tool Execution (`gen_ai.execute_tool`)

Wraps tool/function executions. Captures:
- Tool name
- Tool input
- Tool output

```ruby
with_tool_span(tool_name: "weather_lookup", tool_input: { city: "NYC" }) do
  weather_api.get_forecast("NYC")
end
```

### Handoff (`gen_ai.handoff`)

Tracks stage transitions or agent handoffs.

```ruby
with_handoff_span(from_stage: "greeting", to_stage: "qualification") do
  update_conversation_stage!
end
```

## Graceful Degradation

All instrumentation methods gracefully degrade when Sentry is not available or tracing is disabled. Your code will continue to work normally without any errors.

```ruby
# Works fine even without Sentry initialized
with_chat_span(model: "claude-3-5-sonnet") do
  llm_client.chat(messages)  # Still executes, just without tracing
end
```

## Development

After checking out the repo, run:

```bash
bundle install
rake test      # Run tests
rake rubocop   # Run linter
rake           # Run both
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/sentry-agents/sentry-agents-ruby.

## License

The gem is available as open source under the terms of the [MIT License](LICENSE).
