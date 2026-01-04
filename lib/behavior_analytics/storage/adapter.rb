# frozen_string_literal: true

module BehaviorAnalytics
  module Storage
    class Adapter
      def save_events(events)
        raise NotImplementedError, "#{self.class} must implement #save_events"
      end

      def events_for_context(context, options = {})
        raise NotImplementedError, "#{self.class} must implement #events_for_context"
      end

      def delete_old_events(before_date)
        raise NotImplementedError, "#{self.class} must implement #delete_old_events"
      end

      def event_count(context, options = {})
        raise NotImplementedError, "#{self.class} must implement #event_count"
      end

      def unique_users(context, options = {})
        raise NotImplementedError, "#{self.class} must implement #unique_users"
      end
    end
  end
end

