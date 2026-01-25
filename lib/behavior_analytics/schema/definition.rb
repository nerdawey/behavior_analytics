# frozen_string_literal: true

module BehaviorAnalytics
  module Schema
    class Definition
      attr_reader :name, :version, :required_fields, :field_types, :custom_rules

      def initialize(name, version: "1.0", &block)
        @name = name
        @version = version
        @required_fields = []
        @field_types = {}
        @custom_rules = []
        
        instance_eval(&block) if block_given?
      end

      def required(*fields)
        @required_fields.concat(fields.map(&:to_s))
      end

      def field(field_name, type:)
        @field_types[field_name.to_s] = type
      end

      def validate(&block)
        @custom_rules << block
      end

      def to_h
        {
          name: @name,
          version: @version,
          required_fields: @required_fields,
          field_types: @field_types,
          custom_rules_count: @custom_rules.size
        }
      end
    end

    class Registry
      def initialize
        @schemas = {}
        @mutex = Mutex.new
      end

      def register(schema_definition)
        @mutex.synchronize do
          key = "#{schema_definition.name}@#{schema_definition.version}"
          @schemas[key] = schema_definition
        end
      end

      def get(name, version: "1.0")
        key = "#{name}@#{version}"
        @schemas[key]
      end

      def list
        @schemas.values.map(&:to_h)
      end

      def clear
        @mutex.synchronize do
          @schemas.clear
        end
      end
    end
  end
end

