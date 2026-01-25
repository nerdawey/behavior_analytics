# frozen_string_literal: true

module BehaviorAnalytics
  module Processors
    class BackgroundJobProcessor < AsyncProcessor
      JOB_CLASSES = {
        sidekiq: "BehaviorAnalytics::Jobs::SidekiqEventJob",
        delayed_job: "BehaviorAnalytics::Jobs::DelayedEventJob",
        active_job: "BehaviorAnalytics::Jobs::ActiveEventJob"
      }.freeze

      def initialize(storage_adapter:, queue_name: "default", priority: 0, adapter: :active_job)
        super(storage_adapter: storage_adapter, queue_name: queue_name, priority: priority)
        @adapter = adapter.to_sym
        @job_class = resolve_job_class
      end

      def process_async(events)
        events.each_slice(100) do |batch|
          enqueue_batch(batch)
        end
      end

      private

      def resolve_job_class
        class_name = JOB_CLASSES[@adapter]
        return class_name.constantize if defined?(class_name.constantize)

        case @adapter
        when :sidekiq
          require_sidekiq
          BehaviorAnalytics::Jobs::SidekiqEventJob
        when :delayed_job
          require_delayed_job
          BehaviorAnalytics::Jobs::DelayedEventJob
        when :active_job
          require_active_job
          BehaviorAnalytics::Jobs::ActiveEventJob
        else
          raise Error, "Unsupported job adapter: #{@adapter}"
        end
      end

      def enqueue_batch(batch)
        events_data = batch.map(&:to_h)
        
        case @adapter
        when :sidekiq
          @job_class.set(queue: @queue_name).perform_async(events_data)
        when :delayed_job
          @job_class.new(events_data, @storage_adapter).delay(queue: @queue_name).perform
        when :active_job
          @job_class.set(queue: @queue_name).perform_later(events_data, @storage_adapter)
        end
      end

      def require_sidekiq
        require "sidekiq" unless defined?(Sidekiq)
      end

      def require_delayed_job
        require "delayed_job" unless defined?(Delayed::Job)
      end

      def require_active_job
        require "active_job" unless defined?(ActiveJob)
      end
    end
  end
end

