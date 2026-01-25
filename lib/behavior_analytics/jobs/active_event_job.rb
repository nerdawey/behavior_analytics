# frozen_string_literal: true

begin
  require "active_job"
rescue LoadError
  raise LoadError, "ActiveJob is required for ActiveEventJob. Please add 'activejob' to your Gemfile."
end

module BehaviorAnalytics
  module Jobs
    class ActiveEventJob < ActiveJob::Base
      queue_as :default

      retry_on StandardError, wait: :exponentially_longer, attempts: 3

      def perform(events_data, storage_adapter_class = nil)
        storage_adapter = resolve_storage_adapter(storage_adapter_class)
        events = events_data.map { |data| Event.new(data) }
        storage_adapter.save_events(events)
      rescue StandardError => e
        Rails.logger.error("BehaviorAnalytics: Failed to process events: #{e.message}") if defined?(Rails)
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

