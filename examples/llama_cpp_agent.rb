# frozen_string_literal: true

require "bundler/inline"

gemfile do
  source "https://rubygems.org"
  gem "bigdecimal"
  gem "dotenv"
  gem "json-schema"
end

# Load local gems
$LOAD_PATH.unshift(File.expand_path("../../ollama-client/lib", __dir__))
$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "ollama_client"
require "ollama/agent"

puts "🦙 Initializing Llama.cpp Agent..."

# 1. Setup Config for llama.cpp server
# Assumes llama-server is running at /home/nemesis/llama.cpp/llama-server
config = Ollama::Config.new
config.provider = :llama_cpp
config.base_url = "http://localhost:8080" # Default llama-server port
config.model = "llama" # Name doesn't matter much for llama.cpp but required by client

client = Ollama::Client.new(config: config)

# 2. Define Tools
registry = Ollama::Agent::ToolRegistry.new

registry.define(:get_system_info, description: "Get basic information about the host system") do
  handler do
    puts "  🔧 [Tool] Executing get_system_info..."
    {
      os: RUBY_PLATFORM,
      ruby_version: RUBY_VERSION,
      time: Time.now.to_s
    }
  end
end

registry.define(:calculate, description: "Perform basic math") do
  param :expression, type: :string, description: "Math expression to evaluate", required: true
  handler do |expression:|
    puts "  🔧 [Tool] Calculating: #{expression}..."
    # Warning: simple eval for demo only!
    begin
      eval(expression.gsub(/[^0-9\+\-\*\/\(\)\. ]/, ""))
    rescue StandardError => e
      "Error: #{e.message}"
    end
  end
end

# 3. Setup Executor
executor = Ollama::Agent::Executor.new(
  client: client,
  model: client.config.model,
  tools: registry
)

# 4. Run the Agent
puts "\n💬 User: Tell me about my system and calculate 123 * 456."

begin
  # Check if server is up
  Net::HTTP.get(URI("#{config.base_url}/health"))
  
  result = executor.run(
    messages: [
      { role: "user", content: "Tell me about my system and calculate 123 * 456." }
    ]
  )

  puts "\n🎉 Agent Final Answer:"
  puts result[:content]
  puts "\nMetrics: #{result[:iterations]} iterations used."
rescue Errno::ECONNREFUSED
  puts "\n❌ Error: Could not connect to llama.cpp server at #{config.base_url}"
  puts "   Make sure to start it first:"
  puts "   cd /home/nemesis/llama.cpp && ./llama-server -m models/your-model.gguf --port 8080"
rescue StandardError => e
  puts "\n❌ Agent encountered an error: #{e.message}"
  puts e.backtrace.first(5)
end
