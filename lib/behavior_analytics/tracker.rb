# frozen_string_literal: true

require "securerandom"
require "thread"

module BehaviorAnalytics
  class Tracker
    attr_reader :storage_adapter, :batch_size, :flush_interval, :context_resolver, :async_processor, :event_stream

    def initialize(options = {})
      @storage_adapter = options[:storage_adapter] || BehaviorAnalytics.configuration.storage_adapter || Storage::InMemoryAdapter.new
      @batch_size = options[:batch_size] || BehaviorAnalytics.configuration.batch_size
      @flush_interval = options[:flush_interval] || BehaviorAnalytics.configuration.flush_interval
      @context_resolver = options[:context_resolver] || BehaviorAnalytics.configuration.context_resolver
      @async_processor = options[:async_processor] || BehaviorAnalytics.configuration.async_processor
      @use_async = options.fetch(:use_async, BehaviorAnalytics.configuration.use_async || false)
      @event_stream = options[:event_stream] || BehaviorAnalytics.configuration.event_stream || Streaming::EventStream.new
      @hooks_manager = options[:hooks_manager] || BehaviorAnalytics.configuration.hooks_manager || Hooks::Manager.new
      @sampling_strategy = options[:sampling_strategy] || BehaviorAnalytics.configuration.sampling_strategy
      @rate_limiter = options[:rate_limiter] || BehaviorAnalytics.configuration.rate_limiter
      @schema_validator = options[:schema_validator] || BehaviorAnalytics.configuration.schema_validator
      @metrics = options[:metrics] || BehaviorAnalytics.configuration.metrics || Observability::Metrics.new
      @tracer = options[:tracer] || BehaviorAnalytics.configuration.tracer

      @buffer = []
      @mutex = Mutex.new
      @flush_timer = nil
      start_flush_timer
    end

    def track(context:, event_name:, event_type: :custom, metadata: {}, **options)
      context = normalize_context(context)
      context.validate!

      # Check rate limiting
      if @rate_limiter
        limit_check = @rate_limiter.check_limit(context)
        unless limit_check[:allowed]
          raise Error, "Rate limit exceeded: #{limit_check[:reason]}"
        end
      end

      # Check sampling
      if @sampling_strategy
        event_data = {
          tenant_id: context.tenant_id,
          user_id: context.user_id,
          event_name: event_name,
          event_type: event_type
        }
        unless @sampling_strategy.should_sample?(event_data, context)
          return # Skip this event
        end
      end

      # Build event data
      event_data = {
        tenant_id: context.tenant_id,
        user_id: context.user_id,
        user_type: context.user_type,
        event_name: event_name,
        event_type: event_type,
        metadata: metadata.merge(context.filters),
        session_id: options[:session_id],
        ip: options[:ip],
        user_agent: options[:user_agent],
        duration_ms: options[:duration_ms]
      }

      # Validate schema if validator is configured
      if @schema_validator
        validation_result = @schema_validator.validate(event_data)
        unless validation_result[:valid]
          raise Error, "Event validation failed: #{validation_result[:errors].join(', ')}"
        end
      end

      event = Event.new(event_data)

      # Execute before_track hooks
      begin
        @hooks_manager.execute_before_track(event.to_h, context.to_h)
      rescue StandardError => e
        @hooks_manager.execute_on_error(e, event.to_h, context.to_h)
        raise if BehaviorAnalytics.configuration.raise_on_hook_error
      end

      begin
        # Start tracing if enabled
        span = @tracer&.start_span("track_event", tags: {
          event_name: event_name,
          event_type: event_type.to_s,
          tenant_id: context.tenant_id
        })

        add_to_buffer(event)
        
        # Record metrics
        @metrics.increment_counter("events.tracked", tags: {
          event_type: event_type.to_s,
          tenant_id: context.tenant_id.to_s
        })
        
        # Debug logging
        if BehaviorAnalytics.configuration.debug_mode
          BehaviorAnalytics.configuration.debug("Event tracked: #{event_name}", context: context.to_h)
        end
        
        # Publish to event stream
        @event_stream.publish(event.to_h) if @event_stream
        
        # Execute after_track hooks
        @hooks_manager.execute_after_track(event.to_h, context.to_h)
        
        # Record event for rate limiting
        @rate_limiter.record_event(context) if @rate_limiter

        # Finish tracing
        @tracer&.finish_span(span[:id]) if span
      rescue StandardError => e
        # Record error metrics
        @metrics.increment_counter("events.errors", tags: {
          event_type: event_type.to_s,
          tenant_id: context.tenant_id.to_s
        })
        
        @hooks_manager.execute_on_error(e, event.to_h, context.to_h)
        raise
      end
    end

    def track_api_call(context:, method:, path:, status_code:, duration_ms: nil, **options)
      track(
        context: context,
        event_name: "api_call",
        event_type: :api_call,
        metadata: {
          method: method,
          path: path,
          status_code: status_code
        }.merge(options[:metadata] || {}),
        duration_ms: duration_ms,
        **options
      )
    end

    def track_feature_usage(context:, feature:, metadata: {}, **options)
      track(
        context: context,
        event_name: "feature_usage",
        event_type: :feature_usage,
        metadata: {
          feature: feature
        }.merge(metadata),
        **options
      )
    end

    def flush
      events_to_flush = nil
      @mutex.synchronize do
        return if @buffer.empty?
        events_to_flush = @buffer.dup
        @buffer.clear
      end

      return if events_to_flush.empty?

      start_time = Time.now
      
      begin
        if @use_async && @async_processor
          @async_processor.process_async(events_to_flush)
        else
          @storage_adapter.save_events(events_to_flush)
        end
        
        # Record flush metrics
        duration_ms = ((Time.now - start_time) * 1000).to_i
        @metrics.record_histogram("flush.duration_ms", duration_ms)
        @metrics.increment_counter("flush.count", value: events_to_flush.size)
      rescue StandardError => e
        @metrics.increment_counter("flush.errors")
        raise
      end
      
      restart_flush_timer
    end

    def analytics
      @analytics ||= Analytics::Engine.new(@storage_adapter)
    end

    def query
      Query.new(@storage_adapter)
    end

    def subscribe_to_stream(filter: nil, &block)
      @event_stream.subscribe(filter: filter, &block)
    end

    def inspector
      @inspector ||= Debug::Inspector.new(self)
    end

    private

    def normalize_context(context)
      return context if context.is_a?(Context)
      Context.new(context)
    end

    def add_to_buffer(event)
      @mutex.synchronize do
        @buffer << event
        flush if @buffer.size >= @batch_size
      end
    end

    def start_flush_timer
      return if @flush_interval.nil? || @flush_interval <= 0

      @flush_timer = Thread.new do
        loop do
          sleep @flush_interval
          flush
        end
      end
    end

    def restart_flush_timer
      return if @flush_interval.nil? || @flush_interval <= 0

      @flush_timer&.kill
      start_flush_timer
    end
  end
end

