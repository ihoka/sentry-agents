# frozen_string_literal: true

module Sentry
  module Agents
    # Helper class for building Sentry spans with Gen AI attributes
    #
    # Provides a consistent interface for creating spans across all
    # instrumentation methods.
    #
    class SpanBuilder
      # Mapping of operation types to Sentry span operation names
      OPERATIONS = {
        invoke_agent: "gen_ai.invoke_agent",
        chat: "gen_ai.chat",
        execute_tool: "gen_ai.execute_tool",
        handoff: "gen_ai.handoff"
      }.freeze

      class << self
        # Build and execute a Sentry span
        #
        # @param operation [Symbol] one of :invoke_agent, :chat, :execute_tool, :handoff
        # @param description [String] span description
        # @param attributes [Hash] initial span attributes
        # @yield [Sentry::Span, nil] the created span (or nil if unavailable)
        # @return [Object] the block result
        #
        # @example
        #   SpanBuilder.build(
        #     operation: :chat,
        #     description: "chat claude-3-5-sonnet",
        #     attributes: { "gen_ai.request.model" => "claude-3-5-sonnet" }
        #   ) do |span|
        #     # perform LLM call
        #   end
        #
        def build(operation:, description:, attributes: {})
          return yield(nil) unless sentry_available?

          # Only rescue errors from Sentry span creation itself, not from user code
          span = begin
            create_span(operation, description)
          rescue StandardError => e
            log_span_error(e)
            nil
          end

          # If span creation failed, execute without instrumentation
          return yield(nil) unless span

          # Execute user code within the span - let their exceptions propagate
          begin
            set_attributes(span, attributes)
            yield(span)
          ensure
            # Always finish the span, even if user code raises
            finish_span(span)
          end
        end

        # Set attributes on a span
        #
        # @param span [Sentry::Span, nil] the span to modify
        # @param attributes [Hash] attributes to set
        # @return [void]
        #
        def set_attributes(span, attributes)
          return unless span

          filtered = Serializer.filter(attributes)
          filtered.each do |key, value|
            span.set_data(key, value) if value_present?(value)
          end
        end

        # Check if Sentry tracing is available
        #
        # @return [Boolean] true if Sentry is initialized and has an active span
        #
        def sentry_available?
          defined?(Sentry) &&
            Sentry.initialized? &&
            Sentry.get_current_scope&.get_span
        end

        private

        def create_span(operation, description)
          # Start a child span manually so we control when it finishes
          parent_span = Sentry.get_current_scope&.get_span
          return nil unless parent_span

          parent_span.start_child(
            op: OPERATIONS[operation],
            description: description
          )
        end

        def finish_span(span)
          span&.finish
        rescue StandardError => e
          log_span_error(e)
        end

        def log_span_error(error)
          return unless Sentry::Agents.configuration.debug

          warn "[sentry-agents] Span error: #{error.class} - #{error.message}"
        end

        # Check if a value is present (not nil and not empty if applicable)
        #
        # @param value [Object] the value to check
        # @return [Boolean]
        #
        def value_present?(value)
          return false if value.nil?
          return !value.empty? if value.respond_to?(:empty?)

          true
        end
      end
    end
  end
end
