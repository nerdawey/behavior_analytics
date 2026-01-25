# frozen_string_literal: true

begin
  require "sidekiq"
rescue LoadError
  raise LoadError, "Sidekiq is required for SidekiqEventJob. Please add 'sidekiq' to your Gemfile."
end

module BehaviorAnalytics
  module Jobs
    class SidekiqEventJob
      include Sidekiq::Job

      sidekiq_options retry: 3, backtrace: true

      def perform(events_data, storage_adapter_class = nil)
        storage_adapter = resolve_storage_adapter(storage_adapter_class)
        events = events_data.map { |data| Event.new(data) }
        storage_adapter.save_events(events)
      rescue StandardError => e
        Sidekiq.logger.error("BehaviorAnalytics: Failed to process events: #{e.message}")
        raise
      end

      private

      def resolve_storage_adapter(storage_adapter_class)
        if storage_adapter_class
          storage_adapter_class.constantize.new
        else
          BehaviorAnalytics.configuration.storage_adapter
        end
      end
    end
  end
end

