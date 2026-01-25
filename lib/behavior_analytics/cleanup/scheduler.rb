# frozen_string_literal: true

module BehaviorAnalytics
  module Cleanup
    class Scheduler
      attr_reader :storage_adapter, :retention_policy

      def initialize(storage_adapter:, retention_policy:)
        @storage_adapter = storage_adapter
        @retention_policy = retention_policy
      end

      def cleanup_visits
        return unless storage_adapter.respond_to?(:delete_old_visits)
        
        cutoff_date = retention_policy.visits_cutoff_date
        deleted_count = storage_adapter.delete_old_visits(cutoff_date)
        
        BehaviorAnalytics.configuration.debug("Deleted #{deleted_count} old visits", context: { cutoff_date: cutoff_date })
        deleted_count
      end

      def cleanup_events
        return unless storage_adapter.respond_to?(:delete_old_events)
        
        cutoff_date = retention_policy.events_cutoff_date
        deleted_count = storage_adapter.delete_old_events(cutoff_date)
        
        BehaviorAnalytics.configuration.debug("Deleted #{deleted_count} old events", context: { cutoff_date: cutoff_date })
        deleted_count
      end

      def cleanup_all
        {
          visits: cleanup_visits,
          events: cleanup_events
        }
      end
    end
  end
end

