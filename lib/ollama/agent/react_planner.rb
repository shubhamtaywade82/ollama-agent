# frozen_string_literal: true

module Ollama
  module Agent
    # ReAct-style planner: prepends a Thought/Action/Observation system prompt
    # and delegates the actual chat+tool loop to Executor.
    class ReactPlanner
      DEFAULT_SYSTEM = <<~PROMPT
        You are a ReAct agent. Reason step-by-step using the following loop:

          Thought: describe what you need to figure out next.
          Action: invoke one of the available tools with structured arguments.
          Observation: the tool's result will be provided back to you.

        Repeat Thought / Action / Observation as needed, then produce the final answer.
      PROMPT

      def initialize(client:, model:, tools: nil, system_prompt: DEFAULT_SYSTEM, max_iterations: Executor::DEFAULT_MAX_ITERATIONS)
        @system_prompt = system_prompt
        @executor = Executor.new(client: client, model: model, tools: tools, max_iterations: max_iterations)
      end

      def run(question:, extra_messages: [])
        messages = [{ role: "system", content: @system_prompt }] + extra_messages + [{ role: "user", content: question }]
        @executor.run(messages: messages)
      end
    end
  end
end
