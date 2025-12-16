# AGENTS.md
This file provides guidance to AI coding assistants working in this repository.

**Note:** CLAUDE.md, .clinerules, .cursorrules, .windsurfrules, .replit.md, GEMINI.md, .github/copilot-instructions.md, and .idx/airules.md are symlinks to AGENTS.md in this project.

# Sentry Gen AI Instrumentation Library

A Ruby gem providing Gen AI monitoring capabilities for Ruby applications with AI/LLM agents. Supports multiple LLM providers (Anthropic, OpenAI, Cohere, Google Gemini, etc.) with Sentry SDK integration.

**Version:** 0.1.1
**Ruby:** >= 3.1.0
**License:** MIT

## Build & Commands

### Development Commands

```bash
bundle install              # Install dependencies
bundle exec rake test       # Run entire test suite (Minitest)
bundle exec rake rubocop    # Run linter
bundle exec rake            # Default: runs both test and rubocop
```

### Running Specific Tests

```bash
# Run a specific test file
bundle exec ruby -Itest test/sentry/agents/instrumentation_test.rb

# Run a specific test method
bundle exec ruby -Itest test/sentry/agents/instrumentation_test.rb -n test_method_name
```

### Script Command Consistency

**Important**: When modifying Rake tasks, ensure all references are updated:
- GitHub Actions workflows (.github/workflows/ci.yml)
- README.md documentation

### CI/CD Commands

The CI workflow runs on push and pull requests:
- Tests run on Ruby 3.1, 3.2, 3.3, and 3.4
- Linting runs on Ruby 3.3

### Release Process

```bash
# Create and push a version tag to trigger release
git tag vX.Y.Z
git push origin main --tags
# GitHub Actions automatically: builds gem, publishes to RubyGems, creates GitHub release
```

## Code Style

### Linting Configuration

RuboCop is configured in `.rubocop.yml` with these key rules:

- **Target Ruby Version:** 3.1
- **Max Line Length:** 120 characters
- **String Literals:** Double-quoted (`"string"` not `'string'`)
- **Frozen String Literal:** Required at top of all files

### File Header

Every Ruby file must start with:
```ruby
# frozen_string_literal: true
```

### Naming Conventions

- **Modules/Classes:** PascalCase (`Sentry::Agents::SpanBuilder`)
- **Methods/Variables:** snake_case (`with_agent_span`, `max_string_length`)
- **Constants:** SCREAMING_SNAKE_CASE (`VERSION`)

### Module Structure

Follow the existing namespace pattern:
```ruby
# frozen_string_literal: true

module Sentry
  module Agents
    class YourClass
      # implementation
    end
  end
end
```

### Method Guidelines

- Max method length: 20 lines (instrumentation methods may be longer due to complexity)
- Short parameter names are allowed for Sentry API compatibility
- Implement graceful degradation - methods should work even without Sentry initialized

### Example Code Pattern

```ruby
# frozen_string_literal: true

module Sentry
  module Agents
    module YourModule
      def with_span(description, **attributes)
        return yield unless Sentry.initialized?

        Sentry.with_child_span(op: "gen_ai.operation", description: description) do |span|
          # Set attributes
          span.set_data("gen_ai.system", attributes[:system])
          yield span
        end
      end
    end
  end
end
```

## Testing

### Framework & Setup

**Framework:** Minitest
**Test Pattern:** `test/sentry/agents/*_test.rb`
**Test Helper:** `test/test_helper.rb`

### Test Structure

```ruby
# frozen_string_literal: true

require "test_helper"

class YourTest < Minitest::Test
  include SentryTestHelpers

  def setup
    @instance = YourClass.new
    Sentry::Agents.reset_configuration!
  end

  def teardown
    teardown_sentry
  end

  def test_your_feature
    setup_sentry_with_span
    # test implementation
    assert_equal expected, actual
  end
end
```

### Available Test Helpers

The test helper provides mock objects for Sentry:

- `Sentry::MockScope` - Mocks Sentry scope
- `Sentry::MockSpan` - Mocks span with op, description, data, children tracking
- `setup_sentry_with_span()` - Sets up Sentry mocks with an active span
- `teardown_sentry()` - Cleans up Sentry mocks

### Testing Philosophy

**When tests fail, fix the code, not the test.**

Key principles:
- Tests should be meaningful - avoid tests that always pass regardless of behavior
- Test actual functionality - call the functions being tested
- Failing tests are valuable - they reveal bugs or missing features
- Fix the root cause - when a test fails, fix the underlying issue
- Test edge cases - tests that reveal limitations help improve the code

## Security

### Data Protection

- Use `config.data_filter` to filter sensitive data from spans:
  ```ruby
  Sentry::Agents.configure do |config|
    config.data_filter = ->(data) {
      data.reject { |k, _| k.to_s.include?("api_key") }
    }
  end
  ```

- `max_string_length` limits serialized string data (default: 1000 chars)
- No API keys or credentials should be logged in span data

### Graceful Degradation

All instrumentation methods must work without throwing errors even when Sentry is not initialized. Always check `Sentry.initialized?` before Sentry operations.

## Configuration

### Gem Configuration

```ruby
Sentry::Agents.configure do |config|
  config.default_system = "anthropic"    # Default LLM provider
  config.max_string_length = 1000        # Serialize string limit
  config.debug = false                   # Debug logging
  config.data_filter = ->(data) { ... }  # Custom data filtering
end
```

### Dependencies

**Runtime:**
- `sentry-ruby >= 5.0.0`

**Development:**
- `minitest ~> 5.0`
- `rake ~> 13.0`
- `rubocop ~> 1.21`
- `rubocop-minitest ~> 0.35`

## Directory Structure

```
sentry-agents/
├── lib/
│   ├── sentry-agents.rb              # Main entry point
│   └── sentry/agents/
│       ├── version.rb                # Version constant
│       ├── configuration.rb          # Configuration class
│       ├── instrumentation.rb        # Core instrumentation module
│       ├── span_builder.rb           # SpanBuilder for Sentry spans
│       └── serializer.rb             # Data serialization utility
├── test/
│   ├── test_helper.rb                # Test setup with Sentry mocks
│   └── sentry/agents/
│       └── *_test.rb                 # Test files
├── examples/
│   ├── basic_usage.rb                # Basic example
│   └── multi_provider.rb             # Multi-provider example
├── .github/workflows/
│   ├── ci.yml                        # Test & lint on push/PR
│   └── release.yml                   # Publish on tag
├── reports/                          # All project reports
├── .rubocop.yml                      # Linter configuration
├── Gemfile                           # Dependencies
├── sentry-agents.gemspec             # Gem specification
├── Rakefile                          # Task definitions
└── AGENTS.md                         # This file
```

### Reports Directory

ALL project reports and documentation should be saved to the `reports/` directory:

**Report Types:**
- Implementation summaries: `IMPLEMENTATION_SUMMARY_[FEATURE].md`
- Test results: `TEST_RESULTS_[DATE].md`
- Code quality: `CODE_QUALITY_REPORT.md`

**Naming Conventions:**
- Use descriptive names: `[TYPE]_[SCOPE]_[DATE].md`
- Include dates: `YYYY-MM-DD` format
- Markdown format: All reports end in `.md`

### Temporary Files & Debugging

All temporary files should go in `/temp`:
- Debug scripts: `temp/debug-*.rb`
- Test artifacts: `temp/test-results/`
- Logs: `temp/logs/`

Include `/temp/` in `.gitignore` to prevent accidental commits.

### Claude Code Settings (.claude Directory)

**Version Controlled Files (commit these):**
- `.claude/settings.json` - Shared team settings
- `.claude/commands/*.md` - Custom slash commands
- `.claude/hooks/*.sh` - Hook scripts

**Ignored Files (do NOT commit):**
- `.claude/settings.local.json` - Personal preferences

## Architecture Overview

### Core Components

1. **Instrumentation Module** - Mixin pattern providing span helpers:
   - `with_agent_span()` - Wraps full agent lifecycle (gen_ai.invoke_agent)
   - `with_chat_span()` - Wraps LLM API calls (gen_ai.chat)
   - `with_tool_span()` - Wraps tool execution (gen_ai.execute_tool)
   - `with_handoff_span()` - Tracks stage transitions (gen_ai.handoff)

2. **SpanBuilder** - Creates and manages Sentry spans with proper attributes

3. **Serializer** - Serializes span data with string length limits

4. **Configuration** - Configurable via block with sensible defaults

### Span Types & Attributes

**Span Types Created:**
- `gen_ai.invoke_agent` - Agent invocation wrapper
- `gen_ai.chat` - LLM API call wrapper
- `gen_ai.execute_tool` - Tool/function execution wrapper
- `gen_ai.handoff` - Stage transition tracker

**Common Attributes:**
- `gen_ai.operation.name` - Operation type
- `gen_ai.system` - LLM provider (anthropic, openai, etc.)
- `gen_ai.request.model` - Model identifier
- Token counts (input/output) automatically captured

## Agent Delegation & Tool Execution

### Always Delegate to Specialists

When specialized agents are available, use them instead of attempting tasks yourself.

### Key Principles

- **Agent Delegation**: Check if a specialized agent exists for your task domain
- **Complex Problems**: Delegate to domain experts
- **Multiple Agents**: Send multiple Task tool calls in a single message for parallel execution
- **DEFAULT TO PARALLEL**: Execute multiple tools simultaneously unless sequential is required

### Critical: Always Use Parallel Tool Calls

**Err on the side of maximizing parallel tool calls rather than running sequentially.**

**These cases MUST use parallel tool calls:**
- Searching for different patterns (imports, usage, definitions)
- Multiple grep searches with different regex patterns
- Reading multiple files or searching different directories
- Agent delegations with multiple Task calls to different specialists

**Sequential calls ONLY when:**
You genuinely REQUIRE the output of one tool to determine the usage of the next tool.

**Performance Impact:** Parallel tool execution is 3-5x faster than sequential calls.
