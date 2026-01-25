# frozen_string_literal: true

module BehaviorAnalytics
  module Cleanup
    class RetentionPolicy
      attr_reader :visit_retention_days, :event_retention_days

      def initialize(visit_retention_days: 90, event_retention_days: 365)
        @visit_retention_days = visit_retention_days
        @event_retention_days = event_retention_days
      end

      def should_delete_visit?(visit)
        return false unless visit[:started_at] || visit[:created_at]
        
        visit_date = visit[:started_at] || visit[:created_at]
        cutoff_date = visit_retention_days.days.ago
        
        visit_date < cutoff_date
      end

      def should_delete_event?(event)
        return false unless event[:created_at]
        
        cutoff_date = event_retention_days.days.ago
        event[:created_at] < cutoff_date
      end

      def visits_cutoff_date
        visit_retention_days.days.ago
      end

      def events_cutoff_date
        event_retention_days.days.ago
      end
    end
  end
end

