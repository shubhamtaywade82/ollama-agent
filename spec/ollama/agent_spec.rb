# frozen_string_literal: true

RSpec.describe Ollama::Agent do
  it "has a version number" do
    expect(Ollama::Agent::VERSION).not_to be nil
  end

  describe Ollama::Agent::Tool do
    it "builds JSON schema for Ollama tool API" do
      tool = described_class.new(name: "add", description: "Add two numbers") do
        param :a, type: :number, description: "first"
        param :b, type: :number, description: "second", required: true
      end

      schema = tool.to_ollama_schema
      expect(schema[:type]).to eq("function")
      expect(schema[:function][:name]).to eq("add")
      expect(schema[:function][:description]).to eq("Add two numbers")
      props = schema[:function][:parameters][:properties]
      expect(props[:a][:type]).to eq("number")
      expect(props[:b][:type]).to eq("number")
      expect(schema[:function][:parameters][:required]).to eq(["b"])
    end

    it "invokes the registered handler with keyword args" do
      tool = described_class.new(name: "add") do
        param :a, type: :integer
        param :b, type: :integer
        handler { |a:, b:| a + b }
      end
      expect(tool.call(a: 2, b: 3)).to eq(5)
    end
  end

  describe Ollama::Agent::ToolRegistry do
    let(:registry) { described_class.new }

    it "registers and dispatches by name" do
      registry.define(:echo) do
        param :msg, type: :string
        handler { |msg:| "echo: #{msg}" }
      end
      expect(registry.dispatch("echo", { "msg" => "hi" })).to eq("echo: hi")
    end

    it "raises on unknown tool" do
      expect { registry.dispatch("missing", {}) }
        .to raise_error(Ollama::Agent::UnknownToolError)
    end

    it "exposes all registered tools as Ollama tool schemas" do
      registry.define(:noop) { }
      out = registry.to_ollama_tools
      expect(out.first[:function][:name]).to eq("noop")
    end
  end

  describe Ollama::Agent::ConversationMemory do
    it "appends and trims to sliding window of last N messages" do
      mem = described_class.new(max_messages: 3)
      4.times { |i| mem << { role: "user", content: "m#{i}" } }
      expect(mem.messages.length).to eq(3)
      expect(mem.messages.first[:content]).to eq("m1")
    end

    it "always keeps the system message at the head" do
      mem = described_class.new(max_messages: 2, system: "you are X")
      3.times { |i| mem << { role: "user", content: "m#{i}" } }
      expect(mem.messages.first[:role]).to eq("system")
      expect(mem.messages.first[:content]).to eq("you are X")
      expect(mem.messages.last[:content]).to eq("m2")
    end

    it "trims by approximate token budget when token_budget given" do
      mem = described_class.new(token_budget: 10)
      5.times { |i| mem << { role: "user", content: "a" * 12 } }
      expect(mem.estimated_tokens).to be <= 10
      expect(mem.messages.length).to be < 5
    end
  end

  describe Ollama::Agent::Executor do
    let(:client) { instance_double(Ollama::Client) }
    let(:registry) do
      r = Ollama::Agent::ToolRegistry.new
      r.define(:get_weather) do
        param :city, type: :string
        handler { |city:| "sunny in #{city}" }
      end
      r
    end

    it "returns assistant content when no tool_calls" do
      msg = double(content: "hi there", tool_calls: nil)
      resp = instance_double(Ollama::Response, message: msg, done_reason: "stop")
      expect(client).to receive(:chat).and_return(resp)

      exec = described_class.new(client: client, model: "llama3", tools: registry)
      out = exec.run(messages: [{ role: "user", content: "Say hi" }])
      expect(out[:content]).to eq("hi there")
      expect(out[:iterations]).to eq(1)
    end

    it "executes tool_calls, submits tool response, and continues until stop" do
      tc = double(name: "get_weather", arguments: { "city" => "NYC" })
      first_msg = double(content: nil, tool_calls: [tc])
      first_resp = instance_double(Ollama::Response, message: first_msg, done_reason: "tool_calls")

      final_msg = double(content: "It is sunny in NYC.", tool_calls: nil)
      final_resp = instance_double(Ollama::Response, message: final_msg, done_reason: "stop")

      call_seq = [first_resp, final_resp]
      tool_messages = []
      expect(client).to receive(:chat).twice do |args|
        tool_messages << args[:messages].last
        call_seq.shift
      end

      exec = described_class.new(client: client, model: "llama3", tools: registry)
      out = exec.run(messages: [{ role: "user", content: "weather?" }])
      expect(out[:content]).to eq("It is sunny in NYC.")
      expect(out[:iterations]).to eq(2)
      expect(tool_messages.last[:role]).to eq("tool")
      expect(tool_messages.last[:content]).to eq("sunny in NYC")
    end

    it "halts after max_iterations" do
      tc = double(name: "get_weather", arguments: { "city" => "X" })
      msg = double(content: nil, tool_calls: [tc])
      resp = instance_double(Ollama::Response, message: msg, done_reason: "tool_calls")
      allow(client).to receive(:chat).and_return(resp)

      exec = described_class.new(client: client, model: "llama3", tools: registry, max_iterations: 3)
      out = exec.run(messages: [])
      expect(out[:iterations]).to eq(3)
      expect(out[:halted]).to eq(:max_iterations)
    end
  end

  describe Ollama::Agent::ReactPlanner do
    let(:client) { instance_double(Ollama::Client) }

    it "prepends a ReAct system prompt before running" do
      msg = double(content: "ok", tool_calls: nil)
      resp = instance_double(Ollama::Response, message: msg, done_reason: "stop")
      observed = nil
      expect(client).to receive(:chat) do |args|
        observed = args[:messages]
        resp
      end

      planner = described_class.new(client: client, model: "llama3", tools: Ollama::Agent::ToolRegistry.new)
      planner.run(question: "What is 2+2?")
      expect(observed.first[:role]).to eq("system")
      expect(observed.first[:content]).to match(/Thought|Action|Observation/)
      expect(observed.last[:content]).to eq("What is 2+2?")
    end
  end
end
