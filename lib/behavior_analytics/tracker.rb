# frozen_string_literal: true

require "securerandom"
require "thread"

module BehaviorAnalytics
  class Tracker
    attr_reader :storage_adapter, :batch_size, :flush_interval, :context_resolver

    def initialize(options = {})
      @storage_adapter = options[:storage_adapter] || BehaviorAnalytics.configuration.storage_adapter || Storage::InMemoryAdapter.new
      @batch_size = options[:batch_size] || BehaviorAnalytics.configuration.batch_size
      @flush_interval = options[:flush_interval] || BehaviorAnalytics.configuration.flush_interval
      @context_resolver = options[:context_resolver] || BehaviorAnalytics.configuration.context_resolver

      @buffer = []
      @mutex = Mutex.new
      @flush_timer = nil
      start_flush_timer
    end

    def track(context:, event_name:, event_type: :custom, metadata: {}, **options)
      context = normalize_context(context)
      context.validate!

      event = Event.new(
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
      )

      add_to_buffer(event)
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

      @storage_adapter.save_events(events_to_flush)
      restart_flush_timer
    end

    def analytics
      @analytics ||= Analytics::Engine.new(@storage_adapter)
    end

    def query
      Query.new(@storage_adapter)
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

