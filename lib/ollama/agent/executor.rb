# frozen_string_literal: true

require "json"

module Ollama
  module Agent
    # Drives a chat → tool_calls → tool results loop against an Ollama::Client.
    #
    # Each iteration:
    #   1. Call client.chat with current messages and registered tool schemas.
    #   2. If the assistant returned tool_calls, dispatch each via the registry,
    #      append assistant + tool result messages, and loop.
    #   3. If no tool_calls, return the final content.
    #
    # Halts at `max_iterations` to defend against runaway loops.
    class Executor
      DEFAULT_MAX_ITERATIONS = 8

      def initialize(client:, model:, tools: nil, max_iterations: DEFAULT_MAX_ITERATIONS, hooks: {})
        @client = client
        @model = model
        @tools = tools || ToolRegistry.new
        @max_iterations = max_iterations
        @hooks = hooks
      end

      def run(messages:)
        history = messages.dup
        iterations = 0
        last_content = nil
        halted = nil

        while iterations < @max_iterations
          iterations += 1
          response = @client.chat(
            model: @model,
            messages: history,
            tools: @tools.empty? ? nil : @tools.to_ollama_tools
          )

          msg = response.message
          last_content = msg.content
          calls = msg.tool_calls

          break if calls.nil? || calls.empty?

          history << assistant_message(msg, calls)
          calls.each do |tc|
            result = invoke_tool(tc)
            call_id = (tc.respond_to?(:id) ? tc.id : nil) || "call_#{tc.name}_#{tc.object_id}"
            history << { role: "tool", content: stringify(result), name: tc.name, tool_call_id: call_id }
          end
        end

        halted = :max_iterations if iterations >= @max_iterations && !stopped_cleanly?(history)

        { content: last_content, iterations: iterations, messages: history, halted: halted }
      end

      private

      def stopped_cleanly?(history)
        last = history.last
        return true if last.nil?
        return false if last[:role] == "tool"

        true
      end

      def assistant_message(msg, calls)
        {
          role: "assistant",
          content: msg.content.to_s,
          tool_calls: calls.map do |tc|
            call_id = (tc.respond_to?(:id) ? tc.id : nil) || "call_#{tc.name}_#{tc.object_id}"
            { id: call_id, type: "function", function: { name: tc.name, arguments: tc.arguments } }
          end
        }
      end



      def invoke_tool(tc)
        args = tc.arguments
        args = JSON.parse(args) if args.is_a?(String)
        @tools.dispatch(tc.name, args)
      rescue StandardError => e
        @hooks[:on_tool_error]&.call(tc, e)
        "tool_error: #{e.class}: #{e.message}"
      end

      def stringify(val)
        val.is_a?(String) ? val : val.to_json
      end
    end
  end
end
