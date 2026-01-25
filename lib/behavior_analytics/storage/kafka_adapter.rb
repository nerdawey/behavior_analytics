# frozen_string_literal: true

begin
  require "ruby-kafka"
rescue LoadError
  raise LoadError, "ruby-kafka gem is required for KafkaAdapter. Please add 'ruby-kafka' to your Gemfile."
end

module BehaviorAnalytics
  module Storage
    class KafkaAdapter < Adapter
      def initialize(kafka: nil, topic: "behavior_events", producer: nil)
        @kafka = kafka || Kafka.new(seed_brokers: ["localhost:9092"])
        @topic = topic
        @producer = producer || @kafka.producer
      end

      def save_events(events)
        return if events.empty?

        events.each do |event|
          event_hash = event.is_a?(Hash) ? event : event.to_h
          key = event_hash[:tenant_id] || "default"
          value = serialize_event(event_hash)
          
          @producer.produce(value, topic: @topic, key: key)
        end
        
        @producer.deliver_messages
      rescue StandardError => e
        raise Error, "Failed to save events to Kafka: #{e.message}"
      end

      def events_for_context(context, options = {})
        context.validate!
        
        # Kafka is primarily for streaming, so we need a consumer
        # This is a simplified version - in production you'd use a proper consumer group
        consumer = @kafka.consumer(group_id: "behavior_analytics_#{context.tenant_id}")
        consumer.subscribe(@topic)
        
        events = []
        timeout = options[:timeout] || 5
        
        begin
          consumer.each_message(max_wait_time: timeout) do |message|
            event = deserialize_event(message.value)
            
            if matches_context?(event, context, options)
              events << event
              break if options[:limit] && events.size >= options[:limit]
            end
          end
        rescue Kafka::Error
          # Timeout or other Kafka errors
        ensure
          consumer.stop
        end
        
        events
      end

      def delete_old_events(before_date)
        # Kafka doesn't support deletion of old messages directly
        # Messages are retained based on retention policy
        # This is a no-op for Kafka
      end

      def event_count(context, options = {})
        events_for_context(context, options).count
      end

      def unique_users(context, options = {})
        events = events_for_context(context, options)
        events.map { |e| e[:user_id] }.compact.uniq.count
      end

      private

      def serialize_event(event_hash)
        require "json"
        JSON.generate(event_hash)
      end

      def deserialize_event(data)
        require "json"
        JSON.parse(data, symbolize_names: true)
      end

      def matches_context?(event, context, options)
        return false unless event[:tenant_id] == context.tenant_id
        return false if context.user_id && event[:user_id] != context.user_id
        return false if context.user_type && event[:user_type] != context.user_type
        return false if options[:event_name] && event[:event_name] != options[:event_name]
        return false if options[:event_type] && event[:event_type] != options[:event_type]
        
        if options[:since]
          event_time = Time.parse(event[:created_at].to_s)
          return false if event_time < options[:since]
        end
        
        if options[:until]
          event_time = Time.parse(event[:created_at].to_s)
          return false if event_time > options[:until]
        end
        
        true
      end
    end
  end
end

