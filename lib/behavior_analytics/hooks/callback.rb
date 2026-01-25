# frozen_string_literal: true

module BehaviorAnalytics
  module Hooks
    class Callback
      attr_reader :name, :block, :condition

      def initialize(name, condition: nil, &block)
        @name = name
        @block = block
        @condition = condition
      end

      def call(*args)
        return unless should_execute?(*args)
        @block.call(*args)
      end

      private

      def should_execute?(*args)
        return true unless @condition

        case @condition
        when Proc
          @condition.call(*args)
        when Hash
          event = args[0]
          @condition.all? { |key, value| matches?(event, key, value) }
        when Symbol, String
          event = args[0]
          event[:event_type] == @condition || event[:event_type].to_s == @condition.to_s
        else
          true
        end
      end

      def matches?(event, key, value)
        event_value = event[key.to_sym] || event[key.to_s] || get_metadata_value(event, key.to_s)
        event_value == value || event_value.to_s == value.to_s
      end

      def get_metadata_value(event, key)
        metadata = event[:metadata] || event["metadata"] || {}
        metadata[key.to_sym] || metadata[key.to_s] || metadata[key]
      end
    end
  end
end

