# frozen_string_literal: true

module Ollama
  module Agent
    # Registry of named tools. Builds Ollama tool schemas for `client.chat`
    # and dispatches assistant-emitted tool_calls back to their handlers.
    class ToolRegistry
      def initialize
        @tools = {}
      end

      def define(name, description: nil, &block)
        tool = Tool.new(name: name, description: description, &block)
        @tools[tool.name] = tool
        tool
      end

      def register(tool)
        @tools[tool.name] = tool
      end

      def dispatch(name, arguments)
        tool = @tools[name.to_s] or raise UnknownToolError, "no tool registered as #{name.inspect}"

        kwargs = (arguments || {}).each_with_object({}) { |(k, v), acc| acc[k.to_sym] = v }
        tool.call(**kwargs)
      end

      def to_ollama_tools
        @tools.values.map(&:to_ollama_schema)
      end

      def empty?
        @tools.empty?
      end

      def names
        @tools.keys
      end
    end
  end
end
