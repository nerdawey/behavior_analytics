# frozen_string_literal: true

module BehaviorAnalytics
  class Query
    def initialize(storage_adapter)
      @storage_adapter = storage_adapter
      @context = nil
      @options = {}
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

    def execute
      raise Error, "Context must have tenant_id" unless @context&.valid?
      @storage_adapter.events_for_context(@context, @options)
    end

    def count
      raise Error, "Context must have tenant_id" unless @context&.valid?
      @storage_adapter.event_count(@context, @options)
    end

    private

    def ensure_context
      @context ||= Context.new
    end
  end
end

