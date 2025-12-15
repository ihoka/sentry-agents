# frozen_string_literal: true

module Sentry
  module Agents
    # Core instrumentation module that provides span helper methods
    #
    # Include this module in any class that needs to create Sentry Gen AI spans.
    # All methods are designed to gracefully degrade when Sentry is not available.
    #
    # @example Basic usage
    #   class MyAgent
    #     include Sentry::Agents::Instrumentation
    #
    #     def process(message)
    #       with_agent_span(agent_name: "MyAgent", model: "claude-3-5-sonnet") do
    #         with_chat_span(model: "claude-3-5-sonnet") do
    #           llm_client.chat(message)
    #         end
    #       end
    #     end
    #   end
    #
    module Instrumentation
      # Wrap an agent invocation (e.g., full conversation lifecycle)
      #
      # Creates a gen_ai.invoke_agent span that captures the overall agent execution.
      # Token usage is automatically captured if the block result responds to
      # :input_tokens and :output_tokens.
      #
      # @param agent_name [String] name of the agent (e.g., "Emily", "CustomerService")
      # @param model [String] LLM model identifier (e.g., "claude-3-5-sonnet")
      # @param system [String, nil] override default LLM provider system name
      # @yield the agent logic
      # @return [Object] the block result
      #
      # @example
      #   with_agent_span(agent_name: "Emily", model: "claude-3-5-sonnet") do
      #     process_conversation
      #   end
      #
      def with_agent_span(agent_name:, model:, system: nil)
        return yield unless sentry_tracing_available?

        SpanBuilder.build(
          operation: :invoke_agent,
          description: "invoke_agent #{agent_name}",
          attributes: {
            "gen_ai.operation.name" => "invoke_agent",
            "gen_ai.system" => system_name(system),
            "gen_ai.request.model" => model,
            "gen_ai.agent.name" => agent_name
          }
        ) do |span|
          result = yield
          capture_token_usage(span, result)
          result
        end
      end

      # Wrap an LLM chat API call
      #
      # Creates a gen_ai.chat span that captures a single LLM API call.
      # Automatically captures token usage and response text if available.
      #
      # @param model [String] LLM model identifier
      # @param messages [Array<Hash>, nil] optional message array for the request
      # @param system [String, nil] override default LLM provider system name
      # @yield the LLM call
      # @return [Object] the block result (should respond to :input_tokens, :output_tokens, :content)
      #
      # @example
      #   with_chat_span(model: "claude-3-5-sonnet", messages: conversation_history) do
      #     llm_client.chat(messages)
      #   end
      #
      def with_chat_span(model:, messages: nil, system: nil)
        return yield unless sentry_tracing_available?

        attributes = {
          "gen_ai.operation.name" => "chat",
          "gen_ai.system" => system_name(system),
          "gen_ai.request.model" => model
        }

        if messages
          attributes["gen_ai.request.messages"] = Serializer.serialize(messages)
        end

        SpanBuilder.build(
          operation: :chat,
          description: "chat #{model}",
          attributes: attributes
        ) do |span|
          result = yield
          capture_token_usage(span, result)
          capture_response_text(span, result)
          result
        end
      end

      # Wrap a tool/function execution
      #
      # Creates a gen_ai.execute_tool span that captures tool execution.
      # The tool output is automatically captured from the block result.
      #
      # @param tool_name [String] name of the tool being executed
      # @param tool_input [Hash, String, nil] tool input parameters
      # @param system [String, nil] override default LLM provider system name
      # @yield the tool execution
      # @return [Object] the block result
      #
      # @example
      #   with_tool_span(tool_name: "search", tool_input: { query: "flights" }) do
      #     search_service.search("flights")
      #   end
      #
      def with_tool_span(tool_name:, tool_input: nil, system: nil)
        return yield unless sentry_tracing_available?

        attributes = {
          "gen_ai.operation.name" => "execute_tool",
          "gen_ai.system" => system_name(system),
          "gen_ai.tool.name" => tool_name
        }

        if tool_input
          attributes["gen_ai.tool.input"] = Serializer.serialize(tool_input)
        end

        SpanBuilder.build(
          operation: :execute_tool,
          description: "execute_tool #{tool_name}",
          attributes: attributes
        ) do |span|
          result = yield
          capture_tool_output(span, result)
          result
        end
      end

      # Track agent stage transitions or handoffs
      #
      # Creates a gen_ai.handoff span that captures transitions between
      # stages or handoffs between agents.
      #
      # @param from_stage [String] source stage/agent
      # @param to_stage [String] destination stage/agent
      # @param system [String, nil] override default LLM provider system name
      # @yield the transition logic
      # @return [Object] the block result
      #
      # @example
      #   with_handoff_span(from_stage: "greeting", to_stage: "qualification") do
      #     update_conversation_stage!
      #   end
      #
      def with_handoff_span(from_stage:, to_stage:, system: nil)
        return yield unless sentry_tracing_available?

        SpanBuilder.build(
          operation: :handoff,
          description: "handoff from #{from_stage} to #{to_stage}",
          attributes: {
            "gen_ai.operation.name" => "handoff",
            "gen_ai.system" => system_name(system),
            "gen_ai.handoff.from" => from_stage,
            "gen_ai.handoff.to" => to_stage
          }
        ) do |_span|
          yield
        end
      end

      private

      # Check if Sentry tracing is available
      #
      # @return [Boolean]
      #
      def sentry_tracing_available?
        SpanBuilder.sentry_available?
      end

      # Get system name (provider) from config or override
      #
      # @param override [String, nil]
      # @return [String]
      #
      def system_name(override = nil)
        override || Sentry::Agents.configuration.default_system
      end

      # Capture token usage from result if available
      # Optimized to minimize method calls in hot paths
      #
      # @param span [Sentry::Span, nil]
      # @param result [Object]
      # @return [void]
      #
      def capture_token_usage(span, result)
        return unless span && result

        # Cache values to avoid repeated method lookups
        input_tokens = result.input_tokens if result.respond_to?(:input_tokens)
        output_tokens = result.output_tokens if result.respond_to?(:output_tokens)

        span.set_data("gen_ai.usage.input_tokens", input_tokens) if input_tokens
        span.set_data("gen_ai.usage.output_tokens", output_tokens) if output_tokens
      end

      # Capture response text from result if available
      #
      # @param span [Sentry::Span, nil]
      # @param result [Object]
      # @return [void]
      #
      def capture_response_text(span, result)
        return unless span && result
        return unless result.respond_to?(:content) && result.content

        # Sentry expects response.text as JSON array
        span.set_data("gen_ai.response.text", [result.content].to_json)
      end

      # Capture tool output in span
      #
      # @param span [Sentry::Span, nil]
      # @param result [Object]
      # @return [void]
      #
      def capture_tool_output(span, result)
        return unless span && result

        span.set_data("gen_ai.tool.output", Serializer.serialize(result))
      end
    end
  end
end
