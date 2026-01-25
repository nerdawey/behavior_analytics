# frozen_string_literal: true

module BehaviorAnalytics
  module Sampling
    class Strategy
      def initialize(type:, rate: 1.0, options: {})
        @type = type.to_sym
        @rate = rate.to_f
        @options = options
      end

      def should_sample?(event, context = nil)
        case @type
        when :random
          random_sampling?
        when :deterministic
          deterministic_sampling?(event, context)
        when :adaptive
          adaptive_sampling?(event, context)
        else
          true
        end
      end

      private

      def random_sampling?
        rand < @rate
      end

      def deterministic_sampling?(event, context)
        # Use a hash of tenant_id or user_id for deterministic sampling
        key = context&.tenant_id || event[:tenant_id] || event[:id]
        hash_value = key.hash.abs
        (hash_value % 100) < (@rate * 100)
      end

      def adaptive_sampling?(event, context)
        # Adaptive sampling based on event volume
        # This is a simplified version - in production you'd track actual volume
        base_rate = @rate
        volume_multiplier = @options[:volume_multiplier] || 1.0
        
        # Adjust rate based on current volume (simplified)
        adjusted_rate = base_rate * volume_multiplier
        adjusted_rate = [adjusted_rate, 1.0].min
        adjusted_rate = [adjusted_rate, 0.0].max
        
        rand < adjusted_rate
      end
    end
  end
end

