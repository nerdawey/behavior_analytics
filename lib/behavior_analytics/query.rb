# frozen_string_literal: true

module BehaviorAnalytics
  class Query
    def initialize(storage_adapter)
      @storage_adapter = storage_adapter
      @context = nil
      @options = {}
      @metadata_filters = {}
      @aggregations = []
      @group_by_fields = []
      @where_conditions = []
      @having_conditions = []
    end

    def for_tenant(tenant_id)
      ensure_context
      @context.tenant_id = tenant_id
      self
    end

    def for_user(user_id)
      ensure_context
      @context.user_id = user_id
      self
    end

    def for_user_type(user_type)
      ensure_context
      @context.user_type = user_type
      self
    end

    def with_event_name(event_name)
      @options[:event_name] = event_name
      self
    end

    def with_event_type(event_type)
      @options[:event_type] = event_type
      self
    end

    def since(date)
      @options[:since] = date
      self
    end

    def until(date)
      @options[:until] = date
      self
    end

    def in_range(start_date, end_date)
      since(start_date).until(end_date)
    end

    def limit(n)
      @options[:limit] = n
      self
    end

    def order_by(field, direction = :desc)
      @options[:order_by] = { field: field, direction: direction }
      self
    end

    # Metadata querying methods
    def with_metadata(key, value)
      @metadata_filters[key.to_s] = value
      self
    end

    def with_path(path)
      @options[:path] = path
      self
    end

    def with_path_pattern(pattern)
      @options[:path_pattern] = pattern
      self
    end

    def with_method(method)
      @options[:method] = method.to_s.upcase
      self
    end

    def with_status_code(code)
      @options[:status_code] = code
      self
    end

    # Aggregation methods
    def group_by(field)
      @group_by_fields << field.to_s
      self
    end

    def aggregate(function, field)
      @aggregations << { function: function.to_s.downcase, field: field.to_s }
      self
    end

    def distinct(field)
      @options[:distinct] = field.to_s
      self
    end

    # Advanced filtering
    def where(conditions)
      if conditions.is_a?(Hash)
        @where_conditions << conditions
      else
        @where_conditions << { raw: conditions }
      end
      self
    end

    def having(conditions)
      if conditions.is_a?(Hash)
        @having_conditions << conditions
      else
        @having_conditions << { raw: conditions }
      end
      self
    end

    def join(relation)
      @options[:join] = relation
      self
    end

    def execute
      raise Error, "Context must be valid (have at least tenant_id, user_id, or filters)" unless @context&.valid?
      
      # Merge metadata filters and other options
      final_options = @options.dup
      final_options[:metadata_filters] = @metadata_filters unless @metadata_filters.empty?
      final_options[:aggregations] = @aggregations unless @aggregations.empty?
      final_options[:group_by] = @group_by_fields unless @group_by_fields.empty?
      final_options[:where_conditions] = @where_conditions unless @where_conditions.empty?
      final_options[:having_conditions] = @having_conditions unless @having_conditions.empty?
      
      @storage_adapter.events_for_context(@context, final_options)
    end

    def count
      raise Error, "Context must be valid (have at least tenant_id, user_id, or filters)" unless @context&.valid?
      
      final_options = @options.dup
      final_options[:metadata_filters] = @metadata_filters unless @metadata_filters.empty?
      final_options[:where_conditions] = @where_conditions unless @where_conditions.empty?
      
      @storage_adapter.event_count(@context, final_options)
    end

    private

    def ensure_context
      @context ||= Context.new
    end
  end
end

