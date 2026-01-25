# frozen_string_literal: true

require_relative "behavior_analytics/version"
require_relative "behavior_analytics/event"
require_relative "behavior_analytics/context"
require_relative "behavior_analytics/tracker"
require_relative "behavior_analytics/query"
require_relative "behavior_analytics/storage/adapter"
require_relative "behavior_analytics/storage/in_memory_adapter"
require_relative "behavior_analytics/storage/active_record_adapter"

begin
  require_relative "behavior_analytics/storage/redis_adapter"
rescue LoadError
end

begin
  require_relative "behavior_analytics/storage/elasticsearch_adapter"
rescue LoadError
end

begin
  require_relative "behavior_analytics/storage/kafka_adapter"
rescue LoadError
end
require_relative "behavior_analytics/analytics/engine"
require_relative "behavior_analytics/analytics/funnels"
require_relative "behavior_analytics/analytics/cohorts"
require_relative "behavior_analytics/analytics/retention"
require_relative "behavior_analytics/analytics/geographic"
require_relative "behavior_analytics/analytics/referrer"
require_relative "behavior_analytics/identification/user_resolver"
require_relative "behavior_analytics/cleanup/retention_policy"
require_relative "behavior_analytics/cleanup/scheduler"
require_relative "behavior_analytics/hooks/manager"
require_relative "behavior_analytics/hooks/webhook"
require_relative "behavior_analytics/hooks/callback"
require_relative "behavior_analytics/replay/engine"
require_relative "behavior_analytics/replay/processor"
require_relative "behavior_analytics/sampling/strategy"
require_relative "behavior_analytics/throttling/limiter"
require_relative "behavior_analytics/schema/validator"
require_relative "behavior_analytics/schema/definition"
require_relative "behavior_analytics/export/csv_exporter"
require_relative "behavior_analytics/export/json_exporter"
require_relative "behavior_analytics/reporting/generator"
require_relative "behavior_analytics/observability/metrics"
require_relative "behavior_analytics/observability/tracer"
require_relative "behavior_analytics/debug/inspector"
require_relative "behavior_analytics/processors/async_processor"
require_relative "behavior_analytics/processors/background_job_processor"
require_relative "behavior_analytics/streaming/event_stream"

require_relative "behavior_analytics/visits/visit"
require_relative "behavior_analytics/visits/manager"
require_relative "behavior_analytics/visits/auto_creator"
require_relative "behavior_analytics/detection/device_detector"
require_relative "behavior_analytics/detection/geolocation"

begin
  require_relative "behavior_analytics/integrations/rails"
rescue LoadError
end

begin
  require_relative "behavior_analytics/jobs/active_event_job"
rescue LoadError
end

begin
  require_relative "behavior_analytics/jobs/sidekiq_event_job"
rescue LoadError
end

begin
  require_relative "behavior_analytics/jobs/delayed_event_job"
rescue LoadError
end

module BehaviorAnalytics
  class Error < StandardError
    attr_reader :context

    def initialize(message, context: nil)
      super(message)
      @context = context
    end

    def to_s
      base_message = super
      if @context && BehaviorAnalytics.configuration.debug_mode
        "#{base_message} (Context: #{@context.inspect})"
      else
        base_message
      end
    end
  end

  class ValidationError < Error; end
  class ConfigurationError < Error; end
  class StorageError < Error; end

  class Configuration
    attr_accessor :storage_adapter, :batch_size, :flush_interval, :context_resolver, :scoring_weights,
                  :async_processor, :use_async, :event_stream, :environment, :feature_flags,
                  :hooks_manager, :raise_on_hook_error, :sampling_strategy, :rate_limiter,
                  :schema_validator, :schema_registry, :tracking_whitelist, :tracking_blacklist,
                  :skip_bots, :controller_action_filters, :slow_query_threshold, :track_middleware_requests,
                  :metrics, :tracer, :debug_mode, :logger, :default_tenant_id,
                  :track_visits, :visit_duration, :track_geolocation, :track_device_info,
                  :visit_retention_days, :event_retention_days, :device_detector

    def initialize
      @batch_size = 100
      @flush_interval = 300
      @use_async = false
      @scoring_weights = {
        activity: 0.4,
        unique_users: 0.3,
        feature_diversity: 0.2,
        time_in_trial: 0.1
      }
      @environment = ENV["RAILS_ENV"] || ENV["RACK_ENV"] || "development"
      @feature_flags = {}
      @event_stream = Streaming::EventStream.new
      @hooks_manager = Hooks::Manager.new
      @raise_on_hook_error = false
      @schema_registry = Schema::Registry.new
      @tracking_whitelist = nil
      @tracking_blacklist = []
      @skip_bots = true
      @controller_action_filters = {}
      @slow_query_threshold = nil
      @track_middleware_requests = false
      @metrics = Observability::Metrics.new
      @tracer = nil
      @debug_mode = @environment == "development"
      @logger = nil
      @default_tenant_id = "default" # Default tenant for single-tenant systems
      @track_visits = false
      @visit_duration = 30.minutes
      @track_geolocation = false
      @track_device_info = false
      @visit_retention_days = 90
      @event_retention_days = 365
      @device_detector = :browser
    end

    def debug(message, context: nil)
      return unless @debug_mode

      log_message = "[BehaviorAnalytics] #{message}"
      log_message += " (Context: #{context.inspect})" if context

      if @logger
        @logger.debug(log_message)
      elsif defined?(Rails) && Rails.logger
        Rails.logger.debug(log_message)
      else
        puts log_message
      end
    end

    def log_error(error, context: nil)
      error_message = error.message
      error_message += " (Context: #{context.inspect})" if context

      if @logger
        @logger.error("[BehaviorAnalytics] #{error_message}")
        @logger.error(error.backtrace.join("\n")) if error.backtrace
      elsif defined?(Rails) && Rails.logger
        Rails.logger.error("[BehaviorAnalytics] #{error_message}")
        Rails.logger.error(error.backtrace.join("\n")) if error.backtrace
      else
        puts "[BehaviorAnalytics ERROR] #{error_message}"
        puts error.backtrace.join("\n") if error.backtrace
      end
    end

    def feature_enabled?(feature)
      @feature_flags.fetch(feature, false)
    end

    def enable_feature(feature)
      @feature_flags[feature] = true
    end

    def disable_feature(feature)
      @feature_flags[feature] = false
    end
  end

  class << self
    attr_writer :configuration

    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
    end

    def create_tracker(options = {})
      Tracker.new(options)
    end

    # Simplified API methods
    def track(event_name, properties: {}, event_type: :custom, context: nil, **options)
      # Resolve context automatically if not provided
      context ||= resolve_default_context
      
      tracker = create_tracker
      tracker.track(
        context: context,
        event_name: event_name,
        event_type: event_type,
        metadata: properties,
        **options
      )
    end

    def track_page_view(path:, properties: {}, **options)
      track("page_view", properties: { path: path }.merge(properties), **options)
    end

    def track_click(element:, properties: {}, **options)
      track("click", properties: { element: element }.merge(properties), **options)
    end

    def track_conversion(conversion_name:, value: nil, properties: {}, **options)
      props = { conversion_name: conversion_name }
      props[:value] = value if value
      track("conversion", properties: props.merge(properties), **options)
    end

    def tracker
      @tracker ||= create_tracker
    end

    private

    def resolve_default_context
      # Try to resolve from Rails if available
      if defined?(Rails) && defined?(ActionController::Base)
        # This will be called in controller context
        # For now, return a basic context
        Context.new(tenant_id: configuration.default_tenant_id)
      else
        Context.new(tenant_id: configuration.default_tenant_id)
      end
    end
  end
end

require_relative "behavior_analytics/helpers/tracking_helper"
