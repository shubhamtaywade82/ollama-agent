# frozen_string_literal: true

require "ollama_client"
require_relative "agent/version"

module Ollama
  module Agent
    class Error < StandardError; end
    class UnknownToolError < Error; end
    class NoHandlerError < Error; end
  end
end

require_relative "agent/tool"
require_relative "agent/tool_registry"
require_relative "agent/conversation_memory"
require_relative "agent/executor"
require_relative "agent/react_planner"
