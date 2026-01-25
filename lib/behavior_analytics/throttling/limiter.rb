# frozen_string_literal: true

module BehaviorAnalytics
  module Throttling
    class Limiter
      def initialize(options = {})
        @per_tenant_limits = options[:per_tenant] || {}
        @per_user_limits = options[:per_user] || {}
        @global_limit = options[:global]
        @window_size = options[:window_size] || 60 # seconds
        @counters = {}
        @mutex = Mutex.new
      end

      def check_limit(context, event = nil)
        return { allowed: true } unless should_check_limits?

        @mutex.synchronize do
          # Check global limit
          if @global_limit && !check_global_limit
            return { allowed: false, reason: "global_limit_exceeded" }
          end

          # Check per-tenant limit
          if context.tenant_id && @per_tenant_limits[context.tenant_id]
            limit = @per_tenant_limits[context.tenant_id]
            if !check_limit_for_key("tenant:#{context.tenant_id}", limit)
              return { allowed: false, reason: "tenant_limit_exceeded", tenant_id: context.tenant_id }
            end
          end

          # Check per-user limit
          if context.user_id && @per_user_limits[context.user_id]
            limit = @per_user_limits[context.user_id]
            if !check_limit_for_key("user:#{context.user_id}", limit)
              return { allowed: false, reason: "user_limit_exceeded", user_id: context.user_id }
            end
          end

          { allowed: true }
        end
      end

      def record_event(context)
        return unless should_check_limits?

        @mutex.synchronize do
          increment_counter("global") if @global_limit
          increment_counter("tenant:#{context.tenant_id}") if context.tenant_id && @per_tenant_limits[context.tenant_id]
          increment_counter("user:#{context.user_id}") if context.user_id && @per_user_limits[context.user_id]
        end
      end

      def reset_counters
        @mutex.synchronize do
          @counters.clear
        end
      end

      private

      def should_check_limits?
        @global_limit || !@per_tenant_limits.empty? || !@per_user_limits.empty?
      end

      def check_global_limit
        check_limit_for_key("global", @global_limit)
      end

      def check_limit_for_key(key, limit)
        counter = get_counter(key)
        counter < limit
      end

      def get_counter(key)
        counter = @counters[key]
        
        # Reset counter if window expired
        if counter && counter[:expires_at] < Time.now
          @counters.delete(key)
          counter = nil
        end

        counter ||= { count: 0, expires_at: Time.now + @window_size }
        @counters[key] = counter
        
        counter[:count]
      end

      def increment_counter(key)
        counter = get_counter(key)
        @counters[key][:count] += 1
      end
    end
  end
end

