# frozen_string_literal: true

# Live integration: run Executor and tool-calling against a real Ollama daemon.
# Excluded by default; run with: INTEGRATION=1 bundle exec rspec spec/integration

RSpec.describe Ollama::Agent::Executor, :integration do
  before do
    reason = IntegrationHelper.skip_reason(requires_chat: true)
    skip(reason) if reason
  end

  let(:client) do
    Ollama::Client.new(config: Ollama::Config.new.tap { |c| c.base_url = IntegrationHelper::OLLAMA_URL })
  end
  let(:model) { IntegrationHelper.chat_model }

  it "returns content for a plain question" do
    exec = described_class.new(client: client, model: model)
    out = exec.run(messages: [{ role: "user", content: "Reply with the single word: ok" }])
    expect(out[:content].to_s.length).to be > 0
    expect(out[:iterations]).to be >= 1
  end

  it "finishes (with or without tool calls) within max_iterations when tools are registered" do
    registry = Ollama::Agent::ToolRegistry.new
    registry.define(:add, description: "Add two integers") do
      param :a, type: :integer, required: true
      param :b, type: :integer, required: true
      handler { |a:, b:| a + b }
    end

    exec = described_class.new(client: client, model: model, tools: registry, max_iterations: 3)
    out = exec.run(messages: [{
      role: "user",
      content: "Use the add tool to compute 17 + 25. Reply with only the number."
    }])

    expect(out[:iterations]).to be_between(1, 3).inclusive
    expect(out[:content].to_s.length).to be > 0
  end
end
