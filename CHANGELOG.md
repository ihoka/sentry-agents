# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-12-15

### Added

- Initial release
- Core `Sentry::Agents::Instrumentation` module with span helpers:
  - `with_agent_span` - Wrap agent invocations
  - `with_chat_span` - Wrap LLM chat API calls
  - `with_tool_span` - Wrap tool/function executions
  - `with_handoff_span` - Track stage transitions
- Configuration system with:
  - Configurable default LLM system/provider
  - Max string length for serialization
  - Custom data filtering hooks
  - Debug mode
- `SpanBuilder` helper class for consistent span creation
- `Serializer` utility for data serialization and truncation
- Graceful degradation when Sentry is not available
- Full backward compatibility with `SwiftTail::AiAgentInstrumentation`
