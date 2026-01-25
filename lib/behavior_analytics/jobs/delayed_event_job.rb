# frozen_string_literal: true

begin
  require "delayed_job"
rescue LoadError
  raise LoadError, "DelayedJob is required for DelayedEventJob. Please add 'delayed_job' to your Gemfile."
end

module BehaviorAnalytics
  module Jobs
    class DelayedEventJob
      attr_reader :events_data, :storage_adapter

      def initialize(events_data, storage_adapter = nil)
        @events_data = events_data
        @storage_adapter = storage_adapter || BehaviorAnalytics.configuration.storage_adapter
      end

      def perform
        events = @events_data.map { |data| Event.new(data) }
        @storage_adapter.save_events(events)
      rescue StandardError => e
        Delayed::Worker.logger.error("BehaviorAnalytics: Failed to process events: #{e.message}") if defined?(Delayed::Worker)
        raise
      end
    end
  end
end

