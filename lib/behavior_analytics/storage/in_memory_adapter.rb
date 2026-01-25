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
        
        # Apply metadata filters
        if options[:metadata_filters]
          events = filter_by_metadata(events, options[:metadata_filters])
        end

        # Apply path filtering
        if options[:path]
          events = events.select { |e| get_metadata_value(e, "path") == options[:path] }
        end

        if options[:path_pattern]
          pattern = Regexp.new(options[:path_pattern].gsub('%', '.*'))
          events = events.select { |e| path = get_metadata_value(e, "path"); path && pattern.match?(path) }
        end

        # Apply method filtering
        if options[:method]
          events = events.select { |e| get_metadata_value(e, "method")&.upcase == options[:method].upcase }
        end

        # Apply status code filtering
        if options[:status_code]
          events = events.select { |e| get_metadata_value(e, "status_code")&.to_s == options[:status_code].to_s }
        end

        # Apply where conditions
        if options[:where_conditions]
          events = apply_where_conditions(events, options[:where_conditions])
        end

        # Apply aggregations and group by
        if options[:group_by] && !options[:group_by].empty?
          return apply_group_by(events, options[:group_by], options[:aggregations])
        elsif options[:aggregations] && !options[:aggregations].empty?
          return apply_aggregations(events, options[:aggregations])
        end

        # Apply having conditions (after aggregation - handled in group_by/aggregations)
        # Note: In-memory adapter applies having before returning grouped results

        # Apply distinct
        if options[:distinct]
          seen = {}
          events = events.select do |e|
            value = get_field_value(e, options[:distinct])
            key = value.to_s
            if seen[key]
              false
            else
              seen[key] = true
              true
            end
          end
        end

        # Apply order by
        if options[:order_by]
          events = apply_order_by(events, options[:order_by])
        else
          events = events.sort_by { |e| e[:created_at] || Time.at(0) }.reverse
        end

        # Apply limit
        events = events.first(options[:limit]) if options[:limit]

        events
      end

      def delete_old_events(before_date)
        @mutex.synchronize do
          @events.reject! { |e| e[:created_at] < before_date }
        end
      end

      def event_count(context, options = {})
        # For count, we don't need aggregations/group_by, so use simplified version
        context.validate!
        events = filter_by_context(@events, context)

        events = filter_by_date_range(events, options[:since], options[:until]) if options[:since] || options[:until]
        events = filter_by_event_name(events, options[:event_name]) if options[:event_name]
        events = filter_by_event_type(events, options[:event_type]) if options[:event_type]
        
        if options[:metadata_filters]
          events = filter_by_metadata(events, options[:metadata_filters])
        end

        if options[:path]
          events = events.select { |e| get_metadata_value(e, "path") == options[:path] }
        end

        if options[:method]
          events = events.select { |e| get_metadata_value(e, "method")&.upcase == options[:method].upcase }
        end

        if options[:status_code]
          events = events.select { |e| get_metadata_value(e, "status_code")&.to_s == options[:status_code].to_s }
        end

        if options[:where_conditions]
          events = apply_where_conditions(events, options[:where_conditions])
        end

        events.count
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

      def filter_by_metadata(events, metadata_filters)
        events.select do |event|
          metadata_filters.all? do |key, value|
            get_metadata_value(event, key) == value || get_metadata_value(event, key).to_s == value.to_s
          end
        end
      end

      def get_metadata_value(event, key)
        metadata = event[:metadata] || event["metadata"] || {}
        metadata[key.to_sym] || metadata[key.to_s] || metadata[key]
      end

      def get_field_value(event, field)
        event[field.to_sym] || event[field.to_s] || event[field]
      end

      def apply_where_conditions(events, where_conditions)
        where_conditions.reduce(events) do |filtered, condition|
          if condition[:raw]
            # For raw conditions, we'd need to evaluate them - simplified version
            # In production, you might want to use a proper expression evaluator
            filtered
          else
            condition.reduce(filtered) do |result, (key, value)|
              next result if key == :raw
              result.select { |e| get_field_value(e, key) == value }
            end
          end
        end
      end

      def apply_group_by(events, group_by_fields, aggregations = [])
        grouped = events.group_by do |event|
          group_by_fields.map { |field| get_field_value(event, field) }
        end

        if aggregations && !aggregations.empty?
          grouped.map do |keys, group_events|
            result = {}
            group_by_fields.each_with_index do |field, idx|
              result[field.to_sym] = keys[idx]
            end
            aggregations.each do |agg|
              field = agg[:field]
              func = agg[:function]
              values = group_events.map { |e| get_field_value(e, field) }.compact
              result["#{func}_#{field}".to_sym] = case func
              when "sum"
                values.sum { |v| v.is_a?(Numeric) ? v : 0 }
              when "avg", "average"
                values.empty? ? 0 : values.sum { |v| v.is_a?(Numeric) ? v : 0 }.to_f / values.size
              when "min"
                values.min
              when "max"
                values.max
              when "count"
                values.size
              else
                values.size
              end
            end
            result
          end
        else
          grouped.map do |keys, group_events|
            result = {}
            group_by_fields.each_with_index do |field, idx|
              result[field.to_sym] = keys[idx]
            end
            result[:count] = group_events.size
            result
          end
        end
      end

      def apply_aggregations(events, aggregations)
        result = {}
        aggregations.each do |agg|
          field = agg[:field]
          func = agg[:function]
          values = events.map { |e| get_field_value(e, field) }.compact
          result["#{func}_#{field}".to_sym] = case func
          when "sum"
            values.sum { |v| v.is_a?(Numeric) ? v : 0 }
          when "avg", "average"
            values.empty? ? 0 : values.sum { |v| v.is_a?(Numeric) ? v : 0 }.to_f / values.size
          when "min"
            values.min
          when "max"
            values.max
          when "count"
            values.size
          else
            values.size
          end
        end
        [result]
      end

      def apply_order_by(events, order_by)
        field = order_by[:field]
        direction = order_by[:direction] || :desc
        
        events.sort do |a, b|
          a_val = get_field_value(a, field)
          b_val = get_field_value(b, field)
          
          comparison = if a_val.nil? && b_val.nil?
            0
          elsif a_val.nil?
            1
          elsif b_val.nil?
            -1
          else
            a_val <=> b_val
          end
          
          direction == :desc ? -comparison : comparison
        end
      end
    end
  end
end

