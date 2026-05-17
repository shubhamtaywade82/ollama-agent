# frozen_string_literal: true

module Ollama
  module Agent
    # Conversation history with sliding-window or token-budget truncation.
    # A pinned system message (if set) is always kept at the head of the window.
    class ConversationMemory
      CHARS_PER_TOKEN = 4 # rough heuristic; replace with a tokenizer if precision matters

      attr_reader :system, :max_messages, :token_budget

      def initialize(max_messages: nil, token_budget: nil, system: nil)
        @max_messages = max_messages
        @token_budget = token_budget
        @system = system
        @messages = []
      end

      def <<(message)
        @messages << message
        trim!
        self
      end

      def messages
        head = @system ? [{ role: "system", content: @system }] : []
        head + @messages
      end

      def estimated_tokens
        messages.sum { |m| (m[:content].to_s.length / CHARS_PER_TOKEN.to_f).ceil }
      end

      def clear
        @messages.clear
      end

      private

      def trim!
        @messages.shift while @max_messages && @messages.length > @max_messages
        @messages.shift while @token_budget && estimated_tokens > @token_budget && !@messages.empty?
      end
    end
  end
end
