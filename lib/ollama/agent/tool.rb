# frozen_string_literal: true

module Ollama
  module Agent
    # DSL-defined tool that produces an Ollama-compatible function schema
    # and dispatches structured arguments to a Ruby handler block.
    class Tool
      TYPE_MAP = {
        string: "string", integer: "integer", number: "number",
        boolean: "boolean", array: "array", object: "object"
      }.freeze

      attr_reader :name, :description, :params

      def initialize(name:, description: nil, &block)
        @name = name.to_s
        @description = description
        @params = []
        @handler = nil
        instance_eval(&block) if block
      end

      def param(name, type:, description: nil, required: false, **extra)
        @params << { name: name.to_sym, type: type.to_sym, description: description, required: required, extra: extra }
      end

      def handler(&block)
        @handler = block
      end

      def call(**kwargs)
        raise NoHandlerError, "no handler defined for tool #{@name}" unless @handler

        @handler.call(**kwargs)
      end

      def to_ollama_schema
        properties = {}
        required = []
        @params.each do |p|
          prop = { type: TYPE_MAP.fetch(p[:type], p[:type].to_s) }
          prop[:description] = p[:description] if p[:description]
          prop.merge!(p[:extra]) if p[:extra]&.any?
          properties[p[:name]] = prop
          required << p[:name].to_s if p[:required]
        end

        {
          type: "function",
          function: {
            name: @name,
            description: @description,
            parameters: { type: "object", properties: properties, required: required }
          }.compact
        }
      end
    end
  end
end
