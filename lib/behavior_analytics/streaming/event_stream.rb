# frozen_string_literal: true

module BehaviorAnalytics
  module Streaming
    class EventStream
      attr_reader :subscribers, :filters

      def initialize
        @subscribers = []
        @filters = []
        @mutex = Mutex.new
      end

      def subscribe(filter: nil, &block)
        @mutex.synchronize do
          @subscribers << { filter: filter, callback: block }
        end
        self
      end

      def publish(event)
        @mutex.synchronize do
          @subscribers.each do |subscriber|
            if should_deliver?(event, subscriber[:filter])
              begin
                subscriber[:callback].call(event)
              rescue StandardError => e
                handle_subscriber_error(e, event, subscriber)
              end
            end
          end
        end
      end

      def unsubscribe_all
        @mutex.synchronize do
          @subscribers.clear
        end
      end

      private

      def should_deliver?(event, filter)
        return true unless filter

        case filter
        when Proc
          filter.call(event)
        when Hash
          filter.all? { |key, value| event_matches?(event, key, value) }
        when Symbol, String
          event[:event_type] == filter || event[:event_type].to_s == filter.to_s
        else
          true
        end
      end

      def event_matches?(event, key, value)
        event_value = event[key.to_sym] || event[key.to_s] || get_metadata_value(event, key.to_s)
        event_value == value || event_value.to_s == value.to_s
      end

      def get_metadata_value(event, key)
        metadata = event[:metadata] || event["metadata"] || {}
        metadata[key.to_sym] || metadata[key.to_s] || metadata[key]
      end

      def handle_subscriber_error(error, event, subscriber)
        # Log error but don't stop other subscribers
        if defined?(Rails) && Rails.logger
          Rails.logger.error("BehaviorAnalytics: Subscriber error: #{error.message}")
        end
      end
    end
  end
end

