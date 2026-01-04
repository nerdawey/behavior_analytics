# frozen_string_literal: true

require "securerandom"

module BehaviorAnalytics
  module Storage
    class ActiveRecordAdapter < Adapter
      def initialize(model_class: nil)
        @model_class = model_class || default_model_class
        ensure_model_exists!
      end

      def save_events(events)
        return if events.empty?

        records = events.map do |event|
          event_hash = event.is_a?(Hash) ? event : event.to_h
          {
            id: event_hash[:id] || SecureRandom.uuid,
            tenant_id: event_hash[:tenant_id],
            user_id: event_hash[:user_id],
            user_type: event_hash[:user_type],
            event_name: event_hash[:event_name],
            event_type: event_hash[:event_type].to_s,
            metadata: event_hash[:metadata] || {},
            session_id: event_hash[:session_id],
            ip: event_hash[:ip],
            user_agent: event_hash[:user_agent],
            duration_ms: event_hash[:duration_ms],
            created_at: event_hash[:created_at] || (defined?(Time.current) ? Time.current : Time.now)
          }
        end

        @model_class.insert_all(records)
      rescue StandardError => e
        raise Error, "Failed to save events: #{e.message}"
      end

      def events_for_context(context, options = {})
        context.validate!

        query = @model_class.where(tenant_id: context.tenant_id)
        query = query.where(user_id: context.user_id) if context.user_id
        query = query.where(user_type: context.user_type) if context.user_type

        query = query.where("created_at >= ?", options[:since]) if options[:since]
        query = query.where("created_at <= ?", options[:until]) if options[:until]
        query = query.where(event_name: options[:event_name]) if options[:event_name]
        query = query.where(event_type: options[:event_type].to_s) if options[:event_type]

        query = apply_order_by(query, options[:order_by]) if options[:order_by]
        query = query.limit(options[:limit]) if options[:limit]

        query.map(&:to_h)
      end

      def delete_old_events(before_date)
        @model_class.where("created_at < ?", before_date).delete_all
      end

      def event_count(context, options = {})
        query = build_base_query(context, options)
        query.count
      end

      def unique_users(context, options = {})
        query = build_base_query(context, options)
        query.distinct.count(:user_id)
      end

      private

      def default_model_class
        return BehaviorAnalyticsEvent if defined?(BehaviorAnalyticsEvent)
        raise Error, "BehaviorAnalyticsEvent model not found. Please run the migration generator."
      end

      def ensure_model_exists!
        return if @model_class
        raise Error, "Model class must be provided or BehaviorAnalyticsEvent must be defined"
      end

      def build_base_query(context, options)
        context.validate!

        query = @model_class.where(tenant_id: context.tenant_id)
        query = query.where(user_id: context.user_id) if context.user_id
        query = query.where(user_type: context.user_type) if context.user_type

        query = query.where("created_at >= ?", options[:since]) if options[:since]
        query = query.where("created_at <= ?", options[:until]) if options[:until]
        query = query.where(event_name: options[:event_name]) if options[:event_name]
        query = query.where(event_type: options[:event_type].to_s) if options[:event_type]

        query
      end

      def apply_order_by(query, order_by)
        field = order_by[:field]
        direction = order_by[:direction] || :desc

        if @model_class.column_names.include?(field.to_s)
          query.order("#{field} #{direction.to_s.upcase}")
        else
          query.order(created_at: direction)
        end
      end
    end
  end
end

