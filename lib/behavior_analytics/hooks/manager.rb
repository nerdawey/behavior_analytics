# frozen_string_literal: true

module BehaviorAnalytics
  module Hooks
    class Manager
      attr_reader :before_track_hooks, :after_track_hooks, :on_error_hooks

      def initialize
        @before_track_hooks = []
        @after_track_hooks = []
        @on_error_hooks = []
        @mutex = Mutex.new
      end

      def before_track(condition: nil, &block)
        @mutex.synchronize do
          @before_track_hooks << { condition: condition, callback: block }
        end
        self
      end

      def after_track(condition: nil, &block)
        @mutex.synchronize do
          @after_track_hooks << { condition: condition, callback: block }
        end
        self
      end

      def on_error(condition: nil, &block)
        @mutex.synchronize do
          @on_error_hooks << { condition: condition, callback: block }
        end
        self
      end

      def execute_before_track(event, context)
        execute_hooks(@before_track_hooks, event, context)
      end

      def execute_after_track(event, context)
        execute_hooks(@after_track_hooks, event, context)
      end

      def execute_on_error(error, event, context)
        execute_hooks(@on_error_hooks, error, event, context)
      end

      def clear_all
        @mutex.synchronize do
          @before_track_hooks.clear
          @after_track_hooks.clear
          @on_error_hooks.clear
        end
      end

      private

      def execute_hooks(hooks, *args)
        hooks.each do |hook|
          next if hook[:condition] && !evaluate_condition(hook[:condition], *args)
          
          begin
            hook[:callback].call(*args)
          rescue StandardError => e
            handle_hook_error(e, hook)
          end
        end
      end

      def evaluate_condition(condition, *args)
        case condition
        when Proc
          condition.call(*args)
        when Hash
          # For event/context matching
          event = args[0]
          condition.all? { |key, value| matches?(event, key, value) }
        when Symbol, String
          # Match event type
          event = args[0]
          event[:event_type] == condition || event[:event_type].to_s == condition.to_s
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

      def handle_hook_error(error, hook)
        if defined?(Rails) && Rails.logger
          Rails.logger.error("BehaviorAnalytics: Hook error: #{error.message}")
        end
        # Don't re-raise - allow other hooks to execute
      end
    end
  end
end

