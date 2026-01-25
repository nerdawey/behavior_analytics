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
            visit_id: event_hash[:visit_id],
            visitor_id: event_hash[:visitor_id],
            created_at: event_hash[:created_at] || (defined?(Time.current) ? Time.current : Time.now)
          }
        end

        @model_class.insert_all(records)
      rescue StandardError => e
        raise Error, "Failed to save events: #{e.message}"
      end

      def save_visit(visit_data)
        return unless defined?(BehaviorAnalyticsVisit)
        
        visit_model = BehaviorAnalyticsVisit
        visit_hash = visit_data.is_a?(Hash) ? visit_data : visit_data.to_h
        
        visit = visit_model.find_or_initialize_by(visit_token: visit_hash[:visit_token])
        visit.assign_attributes(visit_hash.except(:visit_token))
        visit.save!
      rescue StandardError => e
        raise Error, "Failed to save visit: #{e.message}"
      end

      def find_active_visit(visitor_token, user_id = nil, visit_duration = 30.minutes)
        return nil unless defined?(BehaviorAnalyticsVisit)
        
        visit_model = BehaviorAnalyticsVisit
        query = visit_model.where(visitor_token: visitor_token)
                          .where(ended_at: nil)
                          .where("started_at > ?", visit_duration.ago)
        
        query = query.where(user_id: user_id) if user_id
        visit = query.order(started_at: :desc).first
        
        visit&.attributes&.symbolize_keys
      end

      def find_visit_by_token(visit_token)
        return nil unless defined?(BehaviorAnalyticsVisit)
        
        visit_model = BehaviorAnalyticsVisit
        visit = visit_model.find_by(visit_token: visit_token)
        visit&.attributes&.symbolize_keys
      end

      def link_user_to_visits(visitor_token, user_id)
        return unless defined?(BehaviorAnalyticsVisit)
        
        visit_model = BehaviorAnalyticsVisit
        visit_model.where(visitor_token: visitor_token, user_id: nil)
                   .update_all(user_id: user_id, updated_at: Time.current)
      end

      def find_visits_by_user(user_id, limit: 100)
        return [] unless defined?(BehaviorAnalyticsVisit)
        
        visit_model = BehaviorAnalyticsVisit
        visits = visit_model.where(user_id: user_id)
                           .order(started_at: :desc)
                           .limit(limit)
        visits.map(&:attributes).map(&:symbolize_keys)
      end

      def find_visits_by_visitor(visitor_token, limit: 100)
        return [] unless defined?(BehaviorAnalyticsVisit)
        
        visit_model = BehaviorAnalyticsVisit
        visits = visit_model.where(visitor_token: visitor_token)
                           .order(started_at: :desc)
                           .limit(limit)
        visits.map(&:attributes).map(&:symbolize_keys)
      end

      def events_for_context(context, options = {})
        context.validate!

        query = build_base_query(context, options)
        
        # If no tenant_id, query all events (for non-multi-tenant systems)
        # This allows tracking without tenant isolation
        
        # Apply metadata filters
        if options[:metadata_filters]
          options[:metadata_filters].each do |key, value|
            query = query.where("metadata->>? = ?", key, value.to_s)
          end
        end

        # Apply path filtering
        if options[:path]
          if column_exists?(:path)
            query = query.where(path: options[:path])
          else
            query = query.where("metadata->>'path' = ?", options[:path])
          end
        end

        if options[:path_pattern]
          if column_exists?(:path)
            query = query.where("path LIKE ?", options[:path_pattern])
          else
            query = query.where("metadata->>'path' LIKE ?", options[:path_pattern])
          end
        end

        # Apply method filtering
        if options[:method]
          if column_exists?(:method)
            query = query.where(method: options[:method])
          else
            query = query.where("metadata->>'method' = ?", options[:method])
          end
        end

        # Apply status code filtering
        if options[:status_code]
          if column_exists?(:status_code)
            query = query.where(status_code: options[:status_code])
          else
            query = query.where("metadata->>'status_code' = ?", options[:status_code].to_s)
          end
        end

        # Apply where conditions
        if options[:where_conditions]
          options[:where_conditions].each do |condition|
            if condition[:raw]
              query = query.where(condition[:raw])
            else
              condition.each do |key, value|
                next if key == :raw
                query = query.where(key => value)
              end
            end
          end
        end

        # Apply aggregations and group by
        if options[:group_by] && !options[:group_by].empty?
          query = apply_group_by(query, options[:group_by], options[:aggregations])
        elsif options[:aggregations] && !options[:aggregations].empty?
          query = apply_aggregations(query, options[:aggregations])
        end

        # Apply having conditions (after aggregation)
        if options[:having_conditions] && (options[:group_by] || options[:aggregations])
          options[:having_conditions].each do |condition|
            if condition[:raw]
              query = query.having(condition[:raw])
            else
              condition.each do |key, value|
                next if key == :raw
                query = query.having(key => value)
              end
            end
          end
        end

        # Apply distinct
        if options[:distinct]
          query = query.distinct(options[:distinct])
        end

        query = apply_order_by(query, options[:order_by]) if options[:order_by]
        query = query.limit(options[:limit]) if options[:limit]

        # Handle aggregations - return hash instead of array
        if options[:aggregations] && !options[:aggregations].empty? && options[:group_by].nil?
          result = query.first
          result ? result.attributes.symbolize_keys : {}
        else
          query.map(&:to_h)
        end
      end

      def delete_old_events(before_date)
        @model_class.where("created_at < ?", before_date).delete_all
      end

      def delete_old_visits(before_date)
        return 0 unless defined?(BehaviorAnalyticsVisit)
        
        visit_model = BehaviorAnalyticsVisit
        visit_model.where("started_at < ?", before_date).delete_all
      end

      def query_visits(context, options = {})
        return [] unless defined?(BehaviorAnalyticsVisit)
        
        visit_model = BehaviorAnalyticsVisit
        query = visit_model.all
        
        query = query.where(tenant_id: context.tenant_id) if context.has_tenant?
        query = query.where(user_id: context.user_id) if context.has_user?
        
        query = query.where("started_at >= ?", options[:since]) if options[:since]
        query = query.where("started_at <= ?", options[:until]) if options[:until]
        query = query.limit(options[:limit]) if options[:limit]
        
        query.map(&:attributes).map(&:symbolize_keys)
      end

      def event_count(context, options = {})
        context.validate!
        query = build_base_query(context, options)
        
        # Apply metadata filters
        if options[:metadata_filters]
          options[:metadata_filters].each do |key, value|
            query = query.where("metadata->>? = ?", key, value.to_s)
          end
        end

        # Apply path/method/status_code filters
        if options[:path]
          if column_exists?(:path)
            query = query.where(path: options[:path])
          else
            query = query.where("metadata->>'path' = ?", options[:path])
          end
        end

        if options[:method]
          if column_exists?(:method)
            query = query.where(method: options[:method])
          else
            query = query.where("metadata->>'method' = ?", options[:method])
          end
        end

        if options[:status_code]
          if column_exists?(:status_code)
            query = query.where(status_code: options[:status_code])
          else
            query = query.where("metadata->>'status_code' = ?", options[:status_code].to_s)
          end
        end

        # Apply where conditions
        if options[:where_conditions]
          options[:where_conditions].each do |condition|
            if condition[:raw]
              query = query.where(condition[:raw])
            else
              condition.each do |key, value|
                next if key == :raw
                query = query.where(key => value)
              end
            end
          end
        end

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

        # Support different business cases:
        # - Multi-tenant: filter by tenant_id
        # - Single-tenant: filter by user_id (tenant_id may be nil)
        # - API-only: no filters required
        query = @model_class.all
        
        if context.has_tenant?
          query = query.where(tenant_id: context.tenant_id)
        end
        
        query = query.where(user_id: context.user_id) if context.has_user?
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

      def apply_group_by(query, group_by_fields, aggregations = [])
        query = query.group(group_by_fields.map(&:to_sym))
        
        if aggregations && !aggregations.empty?
          select_clause = group_by_fields.map { |f| "#{f} as #{f}" }
          aggregations.each do |agg|
            field = agg[:field]
            func = agg[:function]
            select_clause << "#{func.upcase}(#{field}) as #{func}_#{field}"
          end
          query = query.select(select_clause.join(", "))
        else
          query = query.select(group_by_fields.map { |f| "#{f} as #{f}" }.join(", "))
        end
        
        query
      end

      def apply_aggregations(query, aggregations)
        select_clause = []
        aggregations.each do |agg|
          field = agg[:field]
          func = agg[:function]
          select_clause << "#{func.upcase}(#{field}) as #{func}_#{field}"
        end
        query.select(select_clause.join(", "))
      end

      def column_exists?(column_name)
        @model_class.column_names.include?(column_name.to_s)
      end
    end
  end
end

