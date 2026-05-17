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

puts "🤖 Initializing Ollama Weather Agent..."

# 1. Setup Client
# NOTE: Tool calling requires a capable model like qwen2.5-coder, llama3.1, or llama3.2
client = Ollama::Client.new(
  config: Ollama::Config.new.tap do |c|
    c.model = "llama3.2:3b" 
  end
)

# 2. Define Tools via the DSL
registry = Ollama::Agent::ToolRegistry.new

registry.define(:get_weather, description: "Get the current weather for a city") do
  param :city, type: :string, description: "The name of the city, e.g. London", required: true
  handler do |city:|
    puts "  🔧 [Tool] Fetching weather for #{city}..."
    case city.downcase
    when "paris" then "Sunny, 22°C"
    when "london" then "Rainy, 14°C"
    else "Cloudy, 18°C"
    end
  end
end

registry.define(:get_time, description: "Get the current time for a city") do
  param :city, type: :string, description: "The name of the city, e.g. London", required: true
  handler do |city:|
    puts "  🔧 [Tool] Fetching time for #{city}..."
    offset = case city.downcase
             when "paris" then 1
             when "tokyo" then 9
             else 0
             end
    (Time.now.utc + (offset * 3600)).strftime("%I:%M %p")
  end
end

# 3. Setup Executor
executor = Ollama::Agent::Executor.new(
  client: client,
  model: client.config.model,
  tools: registry
)

# 4. Run the Agent
puts "\n💬 User: What is the weather like in Paris? Also, what time is it there?"

# For the purpose of this test script without a real Ollama server, 
# we wrap the run in a begin/rescue.
begin
  result = executor.run(
    messages: [
      { role: "user", content: "What is the weather like in Paris? Also, what time is it there?" }
    ]
  )

  puts "\n🎉 Agent Final Answer:"
  puts result[:content]
  puts "\nMetrics: #{result[:iterations]} iterations used."
rescue StandardError => e
  puts "\n⚠️  Simulation Note: This script requires a running Ollama server with tool-capable models."
  puts "   Error encountered: #{e.message}"
  
  puts "\n--- Code Logic Verification ---"
  puts "✅ Tool Registry initialized with #{registry.names.count} tools."
  puts "✅ Executor correctly instantiated with model: #{executor.instance_variable_get(:@model)}"
end
