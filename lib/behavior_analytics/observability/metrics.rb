# frozen_string_literal: true

module BehaviorAnalytics
  module Observability
    class Metrics
      def initialize
        @counters = {}
        @gauges = {}
        @histograms = {}
        @mutex = Mutex.new
      end

      def increment_counter(name, value: 1, tags: {})
        @mutex.synchronize do
          key = metric_key(name, tags)
          @counters[key] ||= 0
          @counters[key] += value
        end
      end

      def set_gauge(name, value, tags: {})
        @mutex.synchronize do
          key = metric_key(name, tags)
          @gauges[key] = value
        end
      end

      def record_histogram(name, value, tags: {})
        @mutex.synchronize do
          key = metric_key(name, tags)
          @histograms[key] ||= []
          @histograms[key] << value
          # Keep only last 1000 values
          @histograms[key] = @histograms[key].last(1000) if @histograms[key].size > 1000
        end
      end

      def get_counter(name, tags: {})
        key = metric_key(name, tags)
        @counters[key] || 0
      end

      def get_gauge(name, tags: {})
        key = metric_key(name, tags)
        @gauges[key]
      end

      def get_histogram_stats(name, tags: {})
        key = metric_key(name, tags)
        values = @histograms[key] || []
        return {} if values.empty?

        sorted = values.sort
        {
          count: values.size,
          min: sorted.first,
          max: sorted.last,
          sum: values.sum,
          avg: values.sum.to_f / values.size,
          p50: percentile(sorted, 50),
          p95: percentile(sorted, 95),
          p99: percentile(sorted, 99)
        }
      end

      def all_metrics
        {
          counters: @counters.dup,
          gauges: @gauges.dup,
          histograms: @histograms.keys.map { |k| [k, get_histogram_stats(*parse_key(k))] }.to_h
        }
      end

      def reset
        @mutex.synchronize do
          @counters.clear
          @gauges.clear
          @histograms.clear
        end
      end

      private

      def metric_key(name, tags)
        if tags.empty?
          name.to_s
        else
          tag_str = tags.map { |k, v| "#{k}:#{v}" }.join(",")
          "#{name}[#{tag_str}]"
        end
      end

      def parse_key(key)
        if key.include?("[")
          name, tag_str = key.split("[", 2)
          tag_str = tag_str.chomp("]")
          tags = tag_str.split(",").map { |t| t.split(":") }.to_h
          [name, tags]
        else
          [key, {}]
        end
      end

      def percentile(sorted_array, percentile)
        return nil if sorted_array.empty?
        index = (percentile / 100.0) * (sorted_array.size - 1)
        sorted_array[index.floor]
      end
    end
  end
end

