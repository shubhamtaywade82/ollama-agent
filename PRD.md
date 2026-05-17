# Product Requirements Document: ollama-agent

## 1. Product Overview
**Name:** `ollama-agent`
**Role in Ecosystem:** The higher-level orchestration and agent execution layer.
**Goal:** Provide an experimental and highly productive framework for building AI agents, handling tool execution loops, memory management, and multi-turn planning.

## 2. Strategic Positioning
This gem sits at the highest level of the architecture. It is an "Experimental Lab" where orchestration patterns can evolve rapidly. It strictly consumes the deterministic transport and stream contracts defined by `ollama-client` and does NOT attempt to redefine HTTP requests or core error types.

## 3. System Requirements & Features
### 3.1. Agent Execution Loop
- **Executor:** A robust runtime loop that automatically handles `tool_calls` returned by the model, executes local ruby methods, and submits `tool` responses back to the chat context.
- **Planners:** Abstractions for ReAct (Reasoning and Acting) loops and Plan-and-Solve strategies.

### 3.2. Memory & State Management
- **Conversation State:** Interfaces for managing long-running conversation histories (e.g., sliding window, token-aware truncation).
- **Vector Memory (Optional/Interface):** Abstractions to easily inject RAG context into the agent's prompt via standard embeddings.

### 3.3. Tool Registry
- **Tool Definitions:** A DSL to easily define tools (functions) in Ruby, which automatically generate the required JSON Schema format for Ollama's tool API.

## 4. Implementation Details
- **Dependencies:** `ollama-client`.
- **Architecture:** Compose behavior using the `ollama-client`'s chat module. The execution loop should be resilient, utilizing the client's built-in schema repair and retry mechanics.

## 5. Non-Goals
- Do not implement custom HTTP clients or reinvent stream parsing.
- Do not build a monolithic standard library of tools (allow users to bring their own).
