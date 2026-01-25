# frozen_string_literal: true

require "securerandom"

module BehaviorAnalytics
  module Observability
    class Tracer
      attr_reader :correlation_id

      def initialize(correlation_id: nil)
        @correlation_id = correlation_id || generate_correlation_id
        @spans = []
        @mutex = Mutex.new
      end

      def start_span(name, tags: {})
        span = {
          id: SecureRandom.uuid,
          name: name,
          start_time: Time.now,
          tags: tags,
          correlation_id: @correlation_id
        }
        
        @mutex.synchronize do
          @spans << span
        end
        
        span
      end

      def finish_span(span_id, tags: {})
        @mutex.synchronize do
          span = @spans.find { |s| s[:id] == span_id }
          return unless span

          span[:end_time] = Time.now
          span[:duration_ms] = ((span[:end_time] - span[:start_time]) * 1000).to_i
          span[:tags].merge!(tags)
        end
      end

      def add_tags_to_span(span_id, tags)
        @mutex.synchronize do
          span = @spans.find { |s| s[:id] == span_id }
          return unless span

          span[:tags].merge!(tags)
        end
      end

      def get_spans
        @spans.dup
      end

      def get_trace
        {
          correlation_id: @correlation_id,
          spans: @spans,
          total_duration_ms: calculate_total_duration
        }
      end

      private

      def generate_correlation_id
        "#{Time.now.to_i}-#{SecureRandom.hex(8)}"
      end

      def calculate_total_duration
        return 0 if @spans.empty?

        start_times = @spans.map { |s| s[:start_time] }.compact
        end_times = @spans.map { |s| s[:end_time] || Time.now }.compact

        return 0 if start_times.empty? || end_times.empty?

        earliest_start = start_times.min
        latest_end = end_times.max
        ((latest_end - earliest_start) * 1000).to_i
      end
    end
  end
end

