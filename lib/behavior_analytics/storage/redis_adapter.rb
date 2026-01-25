# frozen_string_literal: true

begin
  require "redis"
rescue LoadError
  raise LoadError, "Redis gem is required for RedisAdapter. Please add 'redis' to your Gemfile."
end

module BehaviorAnalytics
  module Storage
    class RedisAdapter < Adapter
      def initialize(redis: nil, key_prefix: "behavior_analytics", ttl: nil)
        @redis = redis || Redis.new
        @key_prefix = key_prefix
        @ttl = ttl
      end

      def save_events(events)
        return if events.empty?

        events.each do |event|
          event_hash = event.is_a?(Hash) ? event : event.to_h
          key = event_key(event_hash)
          @redis.setex(key, @ttl || 86400, serialize_event(event_hash))
          
          # Add to index sets
          index_event(event_hash)
        end
      rescue StandardError => e
        raise Error, "Failed to save events to Redis: #{e.message}"
      end

      def events_for_context(context, options = {})
        context.validate!

        # Get event IDs from index
        event_ids = find_event_ids(context, options)
        
        # Fetch events
        events = event_ids.map do |id|
          deserialize_event(@redis.get("#{@key_prefix}:event:#{id}"))
        end.compact

        # Apply filters that can't be done in Redis
        events = filter_events(events, context, options)
        
        # Apply limit and ordering
        events = sort_events(events, options[:order_by]) if options[:order_by]
        events = events.first(options[:limit]) if options[:limit]

        events
      end

      def delete_old_events(before_date)
        # Redis TTL handles expiration, but we can also scan and delete
        pattern = "#{@key_prefix}:event:*"
        @redis.scan_each(match: pattern) do |key|
          event = deserialize_event(@redis.get(key))
          if event && event[:created_at] && Time.parse(event[:created_at].to_s) < before_date
            @redis.del(key)
            remove_from_indexes(event)
          end
        end
      end

      def event_count(context, options = {})
        context.validate!
        find_event_ids(context, options).count
      end

      def unique_users(context, options = {})
        context.validate!
        event_ids = find_event_ids(context, options)
        events = event_ids.map { |id| deserialize_event(@redis.get("#{@key_prefix}:event:#{id}")) }.compact
        events.map { |e| e[:user_id] }.compact.uniq.count
      end

      private

      def event_key(event_hash)
        id = event_hash[:id] || SecureRandom.uuid
        "#{@key_prefix}:event:#{id}"
      end

      def serialize_event(event_hash)
        require "json"
        JSON.generate(event_hash)
      end

      def deserialize_event(data)
        return nil unless data
        require "json"
        JSON.parse(data, symbolize_names: true)
      end

      def index_event(event_hash)
        tenant_id = event_hash[:tenant_id]
        user_id = event_hash[:user_id]
        event_type = event_hash[:event_type]
        
        @redis.sadd("#{@key_prefix}:tenant:#{tenant_id}", event_hash[:id])
        @redis.sadd("#{@key_prefix}:user:#{user_id}", event_hash[:id]) if user_id
        @redis.sadd("#{@key_prefix}:type:#{event_type}", event_hash[:id]) if event_type
      end

      def remove_from_indexes(event_hash)
        tenant_id = event_hash[:tenant_id]
        user_id = event_hash[:user_id]
        event_type = event_hash[:event_type]
        
        @redis.srem("#{@key_prefix}:tenant:#{tenant_id}", event_hash[:id])
        @redis.srem("#{@key_prefix}:user:#{user_id}", event_hash[:id]) if user_id
        @redis.srem("#{@key_prefix}:type:#{event_type}", event_hash[:id]) if event_type
      end

      def find_event_ids(context, options)
        # Start with tenant index
        ids = @redis.smembers("#{@key_prefix}:tenant:#{context.tenant_id}").to_a
        
        # Intersect with user index if specified
        if context.user_id
          user_ids = @redis.smembers("#{@key_prefix}:user:#{context.user_id}").to_a
          ids = ids & user_ids
        end
        
        # Intersect with event type if specified
        if options[:event_type]
          type_ids = @redis.smembers("#{@key_prefix}:type:#{options[:event_type]}").to_a
          ids = ids & type_ids
        end
        
        ids
      end

      def filter_events(events, context, options)
        events.select do |event|
          matches = true
          
          matches &&= event[:user_type] == context.user_type if context.user_type
          matches &&= event[:event_name] == options[:event_name] if options[:event_name]
          
          if options[:since]
            matches &&= Time.parse(event[:created_at].to_s) >= options[:since]
          end
          
          if options[:until]
            matches &&= Time.parse(event[:created_at].to_s) <= options[:until]
          end
          
          if options[:metadata_filters]
            options[:metadata_filters].each do |key, value|
              metadata = event[:metadata] || {}
              matches &&= (metadata[key.to_sym] == value || metadata[key.to_s] == value)
            end
          end
          
          matches
        end
      end

      def sort_events(events, order_by)
        field = order_by[:field]
        direction = order_by[:direction] || :desc
        
        events.sort do |a, b|
          a_val = a[field.to_sym] || a[field.to_s]
          b_val = b[field.to_sym] || b[field.to_s]
          comparison = (a_val <=> b_val) || 0
          direction == :desc ? -comparison : comparison
        end
      end
    end
  end
end

