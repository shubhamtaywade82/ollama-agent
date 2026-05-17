# frozen_string_literal: true

module Ollama
  module Agent
    # Plan-and-Solve planner: prepends a system prompt instructing the model
    # to first devise a step-by-step plan and then execute the plan using tools.
    class PlanAndSolvePlanner
      DEFAULT_SYSTEM = <<~PROMPT
        You are a Plan-and-Solve agent. Before taking action, first understand the goal and devise a clear, step-by-step plan.

        Follow this structure:
        1. Plan: List the step-by-step actions required to solve the task.
        2. Execute: Carry out each planned step sequentially using available tools.
        3. Final Answer: Once all steps are complete, provide the comprehensive final answer.
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
