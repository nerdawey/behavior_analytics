# frozen_string_literal: true

module BehaviorAnalytics
  module Helpers
    module TrackingHelper
      def track_event(event_name, properties: {}, event_type: :custom, **options)
        context = resolve_tracking_context
        return unless context&.valid?

        tracker.track(
          context: context,
          event_name: event_name,
          event_type: event_type,
          metadata: properties,
          **options
        )
      end

      def track_page_view(path: nil, properties: {}, **options)
        path ||= request.path if respond_to?(:request)
        track_event("page_view", properties: { path: path }.merge(properties), **options)
      end

      def track_click(element:, properties: {}, **options)
        track_event("click", properties: { element: element }.merge(properties), **options)
      end

      def track_form_submit(form_name:, properties: {}, **options)
        track_event("form_submit", properties: { form_name: form_name }.merge(properties), **options)
      end

      def track_conversion(conversion_name:, value: nil, properties: {}, **options)
        props = { conversion_name: conversion_name }
        props[:value] = value if value
        track_event("conversion", properties: props.merge(properties), **options)
      end

      private

      def resolve_tracking_context
        # Try to resolve context from current request/controller
        if respond_to?(:current_user, true)
          Context.new(
            tenant_id: respond_to?(:current_tenant, true) ? current_tenant&.id : BehaviorAnalytics.configuration.default_tenant_id,
            user_id: current_user&.id,
            user_type: current_user&.account_type || current_user&.user_type
          )
        elsif respond_to?(:request, true) && request.respond_to?(:remote_ip)
          # Anonymous tracking
          Context.new(
            tenant_id: BehaviorAnalytics.configuration.default_tenant_id
          )
        else
          # Fallback to default context
          Context.new(
            tenant_id: BehaviorAnalytics.configuration.default_tenant_id
          )
        end
      end

      def tracker
        @tracker ||= BehaviorAnalytics.create_tracker
      end
    end
  end
end

