# frozen_string_literal: true

begin
  require "active_support/concern"
rescue LoadError
end

module BehaviorAnalytics
  module Integrations
    module Rails
      unless defined?(ActiveSupport::Concern)
        raise LoadError, "Rails integration requires ActiveSupport. Please add 'activesupport' to your Gemfile."
      end

      extend ActiveSupport::Concern

      included do
        around_action :track_behavior_analytics, if: :behavior_analytics_enabled?
      end

      class_methods do
        def skip_behavior_tracking(options = {})
          skip_around_action :track_behavior_analytics, options
        end
      end

      private

      def track_behavior_analytics
        start_time = Time.current
        yield
      ensure
        if should_track?
          context = resolve_tracking_context
          if context&.valid?
            duration_ms = ((Time.current - start_time) * 1000).to_i

            behavior_tracker.track_api_call(
              context: context,
              method: request.method,
              path: request.path,
              status_code: response.status,
              duration_ms: duration_ms,
              ip: request.remote_ip,
              user_agent: request.user_agent,
              session_id: session.id,
              metadata: {
                controller: controller_name,
                action: action_name,
                format: request.format.to_s
              }
            )
          end
        end
      end

      def behavior_tracker
        @behavior_tracker ||= BehaviorAnalytics.create_tracker(
          storage_adapter: BehaviorAnalytics.configuration.storage_adapter
        )
      end

      def resolve_tracking_context
        if BehaviorAnalytics.configuration.context_resolver
          resolver_result = BehaviorAnalytics.configuration.context_resolver.call(request)
          Context.new(resolver_result)
        elsif respond_to?(:current_tenant, true) && respond_to?(:current_user, true)
          Context.new(
            tenant_id: current_tenant&.id,
            user_id: current_user&.id,
            user_type: current_user&.account_type || current_user&.user_type
          )
        else
          nil
        end
      end

      def should_track?
        context = resolve_tracking_context
        return false unless context&.valid?

        # Check path whitelist/blacklist
        return false if path_blacklisted?
        return false if path_not_whitelisted?

        # Check user agent filtering
        return false if bot_user_agent?

        # Check controller/action filtering
        return false if controller_action_filtered?

        true
      end

      def path_blacklisted?
        blacklist = BehaviorAnalytics.configuration.tracking_blacklist || []
        return false if blacklist.empty?

        blacklist.any? { |pattern| matches_pattern?(request.path, pattern) }
      end

      def path_not_whitelisted?
        whitelist = BehaviorAnalytics.configuration.tracking_whitelist
        return false unless whitelist && !whitelist.empty?

        !whitelist.any? { |pattern| matches_pattern?(request.path, pattern) }
      end

      def bot_user_agent?
        return false unless BehaviorAnalytics.configuration.skip_bots

        user_agent = request.user_agent.to_s.downcase
        bot_patterns = %w[bot crawler spider crawlerbot googlebot bingbot yandex]
        bot_patterns.any? { |pattern| user_agent.include?(pattern) }
      end

      def controller_action_filtered?
        filters = BehaviorAnalytics.configuration.controller_action_filters || {}
        return false if filters.empty?

        controller_filter = filters[:controllers] || []
        action_filter = filters[:actions] || []

        return true if controller_filter.include?(controller_name)
        return true if action_filter.include?("#{controller_name}##{action_name}")

        false
      end

      def matches_pattern?(path, pattern)
        case pattern
        when Regexp
          pattern.match?(path)
        when String
          path.include?(pattern) || File.fnmatch?(pattern, path)
        else
          false
        end
      end

      def behavior_analytics_enabled?
        BehaviorAnalytics.configuration.storage_adapter.present?
      end

      def track_behavior_analytics
        start_time = Time.current
        error_occurred = false
        error_message = nil
        
        yield
      rescue StandardError => e
        error_occurred = true
        error_message = e.message
        raise
      ensure
        if should_track?
          context = resolve_tracking_context
          if context&.valid?
            duration_ms = ((Time.current - start_time) * 1000).to_i

            # Check for slow queries
            if BehaviorAnalytics.configuration.slow_query_threshold
              if duration_ms > BehaviorAnalytics.configuration.slow_query_threshold
                log_slow_query(duration_ms, request.path)
              end
            end

            behavior_tracker.track_api_call(
              context: context,
              method: request.method,
              path: request.path,
              status_code: response.status,
              duration_ms: duration_ms,
              ip: request.remote_ip,
              user_agent: request.user_agent,
              session_id: session.id,
              metadata: {
                controller: controller_name,
                action: action_name,
                format: request.format.to_s,
                error: error_occurred,
                error_message: error_message
              }.compact
            )
          end
        end
      end

      def log_slow_query(duration_ms, path)
        if defined?(Rails) && Rails.logger
          Rails.logger.warn("BehaviorAnalytics: Slow query detected: #{path} took #{duration_ms}ms")
        end
      end
    end
  end
end

