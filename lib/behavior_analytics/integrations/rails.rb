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

        true
      end

      def behavior_analytics_enabled?
        BehaviorAnalytics.configuration.storage_adapter.present?
      end
    end
  end
end

