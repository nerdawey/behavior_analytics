# frozen_string_literal: true

module BehaviorAnalytics
  module Schema
    class Validator
      def initialize(schema_definition)
        @schema = schema_definition
      end

      def validate(event)
        errors = []

        # Validate required fields
        if @schema.required_fields
          @schema.required_fields.each do |field|
            unless event.key?(field.to_sym) || event.key?(field.to_s)
              errors << "Missing required field: #{field}"
            end
          end
        end

        # Validate field types
        if @schema.field_types
          @schema.field_types.each do |field, expected_type|
            value = event[field.to_sym] || event[field.to_s]
            next if value.nil? # Optional fields can be nil

            unless matches_type?(value, expected_type)
              errors << "Field #{field} has wrong type. Expected #{expected_type}, got #{value.class}"
            end
          end
        end

        # Validate custom rules
        if @schema.custom_rules
          @schema.custom_rules.each do |rule|
            result = evaluate_rule(rule, event)
            unless result[:valid]
              errors << result[:error] || "Validation failed for rule: #{rule}"
            end
          end
        end

        {
          valid: errors.empty?,
          errors: errors
        }
      end

      private

      def matches_type?(value, expected_type)
        case expected_type
        when :string
          value.is_a?(String)
        when :integer
          value.is_a?(Integer)
        when :float, :number
          value.is_a?(Numeric)
        when :boolean
          value.is_a?(TrueClass) || value.is_a?(FalseClass)
        when :hash, :object
          value.is_a?(Hash)
        when :array
          value.is_a?(Array)
        when Class
          value.is_a?(expected_type)
        else
          true
        end
      end

      def evaluate_rule(rule, event)
        case rule
        when Proc
          begin
            result = rule.call(event)
            if result.is_a?(Hash)
              result
            elsif result
              { valid: true }
            else
              { valid: false, error: "Rule validation failed" }
            end
          rescue StandardError => e
            { valid: false, error: e.message }
          end
        when Hash
          # Rule format: { field: { condition: value } }
          rule.all? do |field, condition|
            value = event[field.to_sym] || event[field.to_s]
            evaluate_condition(value, condition)
          end
          { valid: true }
        else
          { valid: true }
        end
      end

      def evaluate_condition(value, condition)
        case condition
        when Hash
          condition.all? { |key, expected| evaluate_condition(value, { key => expected }) }
        when Proc
          condition.call(value)
        else
          value == condition
        end
      end
    end
  end
end

