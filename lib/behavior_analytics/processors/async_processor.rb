# frozen_string_literal: true

module BehaviorAnalytics
  module Processors
    class AsyncProcessor
      attr_reader :storage_adapter, :queue_name, :priority

      def initialize(storage_adapter:, queue_name: "default", priority: 0)
        @storage_adapter = storage_adapter
        @queue_name = queue_name
        @priority = priority
      end

      def process_async(events)
        raise NotImplementedError, "#{self.class} must implement #process_async"
      end

      def process_sync(events)
        @storage_adapter.save_events(events)
      end
    end
  end
end

