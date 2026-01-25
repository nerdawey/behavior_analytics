# frozen_string_literal: true

require "set"

module BehaviorAnalytics
  module Debug
    class Inspector
      def initialize(tracker)
        @tracker = tracker
      end

      def inspect_event(event_id, context)
        context.validate!
        
        events = @tracker.query
          .for_tenant(context.tenant_id)
          .where(id: event_id)
          .execute
        
        return nil if events.empty?
        
        event = events.first
        {
          event: event,
          context: context.to_h,
          metadata: event[:metadata] || {},
          related_events: find_related_events(event, context)
        }
      end

      def inspect_context(context, options = {})
        context.validate!
        
        {
          context: context.to_h,
          event_count: @tracker.analytics.event_count(context, options),
          unique_users: @tracker.analytics.unique_users(context, options),
          active_days: @tracker.analytics.active_days(context, options),
          recent_events: @tracker.query
            .for_tenant(context.tenant_id)
            .limit(10)
            .execute
        }
      end

      def inspect_buffer
        {
          buffer_size: @tracker.instance_variable_get(:@buffer)&.size || 0,
          batch_size: @tracker.batch_size,
          flush_interval: @tracker.flush_interval
        }
      end

      private

      def find_related_events(event, context)
        related = []
        
        # Find events with same session
        if event[:session_id]
          related.concat(@tracker.query
            .for_tenant(context.tenant_id)
            .where(session_id: event[:session_id])
            .limit(10)
            .execute)
        end
        
        # Find events with same correlation_id
        if event[:correlation_id]
          related.concat(@tracker.query
            .for_tenant(context.tenant_id)
            .where(correlation_id: event[:correlation_id])
            .limit(10)
            .execute)
        end
        
        related.uniq { |e| e[:id] }
      end
    end
  end
end

