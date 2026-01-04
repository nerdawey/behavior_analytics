# frozen_string_literal: true

module BehaviorAnalytics
  module Storage
    class InMemoryAdapter < Adapter
      def initialize
        @events = []
        @mutex = Mutex.new
      end

      def save_events(events)
        @mutex.synchronize do
          @events.concat(events.map(&:to_h))
        end
      end

      def events_for_context(context, options = {})
        context.validate!
        events = filter_by_context(@events, context)

        events = filter_by_date_range(events, options[:since], options[:until]) if options[:since] || options[:until]
        events = filter_by_event_name(events, options[:event_name]) if options[:event_name]
        events = filter_by_event_type(events, options[:event_type]) if options[:event_type]

        events = events.sort_by { |e| e[:created_at] }.reverse
        events = events.first(options[:limit]) if options[:limit]

        events
      end

      def delete_old_events(before_date)
        @mutex.synchronize do
          @events.reject! { |e| e[:created_at] < before_date }
        end
      end

      def event_count(context, options = {})
        events_for_context(context, options).count
      end

      def unique_users(context, options = {})
        events = events_for_context(context, options)
        events.map { |e| e[:user_id] }.compact.uniq.count
      end

      def clear
        @mutex.synchronize do
          @events.clear
        end
      end

      private

      def filter_by_context(events, context)
        events.select do |event|
          matches_tenant = event[:tenant_id] == context.tenant_id
          matches_user = context.user_id.nil? || event[:user_id] == context.user_id || event[:user_id].nil?
          matches_user_type = context.user_type.nil? || event[:user_type] == context.user_type || event[:user_type].nil?
          
          matches_tenant && matches_user && matches_user_type
        end
      end

      def filter_by_date_range(events, since, until_date)
        events.select do |event|
          (since.nil? || event[:created_at] >= since) &&
            (until_date.nil? || event[:created_at] <= until_date)
        end
      end

      def filter_by_event_name(events, event_name)
        events.select { |e| e[:event_name] == event_name }
      end

      def filter_by_event_type(events, event_type)
        event_type_sym = event_type.is_a?(Symbol) ? event_type : event_type.to_sym
        events.select { |e| e[:event_type] == event_type_sym || e[:event_type].to_sym == event_type_sym }
      end
    end
  end
end

