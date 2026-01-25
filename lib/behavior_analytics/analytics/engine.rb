# frozen_string_literal: true

require "date"
require "time"
require "active_support/core_ext/date"
require "active_support/core_ext/time"

module BehaviorAnalytics
  module Analytics
    class Engine
      def initialize(storage_adapter)
        @storage_adapter = storage_adapter
        @funnels = nil
        @cohorts = nil
        @retention = nil
        @geographic = nil
        @referrer = nil
      end

      def event_count(context, options = {})
        normalized_context = normalize_context(context)
        normalized_context.validate!
        @storage_adapter.event_count(normalized_context, options)
      end

      def unique_users(context, options = {})
        normalized_context = normalize_context(context)
        normalized_context.validate!
        @storage_adapter.unique_users(normalized_context, options)
      end

      def active_days(context, options = {})
        normalized_context = normalize_context(context)
        normalized_context.validate!

        events = @storage_adapter.events_for_context(normalized_context, options)
        return 0 if events.empty?

        dates = events.map { |e| date_from_event(e) }.compact.uniq
        dates.count
      end

      def engagement_score(context, options = {})
        normalized_context = normalize_context(context)
        normalized_context.validate!

        weights = options[:weights] || BehaviorAnalytics.configuration.scoring_weights

        total_events = event_count(normalized_context, options)
        unique_users_count = unique_users(normalized_context, options)
        active_days_count = active_days(normalized_context, options)
        feature_diversity = feature_count(normalized_context, options)

        events_score = [total_events / 100.0, 1.0].min
        users_score = [unique_users_count / 10.0, 1.0].min
        days_score = [active_days_count / 7.0, 1.0].min
        features_score = [feature_diversity / 5.0, 1.0].min

        score = (events_score * weights[:activity]) +
                (users_score * weights[:unique_users]) +
                (days_score * weights[:time_in_trial]) +
                (features_score * weights[:feature_diversity])

        (score * 100).round(2)
      end

      def activity_timeline(context, options = {})
        period = options.delete(:period) || :daily
        normalized_context = normalize_context(context)
        normalized_context.validate!

        events = @storage_adapter.events_for_context(normalized_context, options)
        return [] if events.empty?

        grouped = case period
                  when :hourly
                    group_by_hour(events)
                  when :daily
                    group_by_day(events)
                  when :weekly
                    group_by_week(events)
                  when :monthly
                    group_by_month(events)
                  else
                    group_by_day(events)
                  end

        grouped.map { |period_key, period_events| [period_key, period_events.count] }.to_h
      end

      def daily_activity(context, options = {})
        normalized_context = normalize_context(context)
        normalized_context.validate!

        options = options.dup
        if options[:date_range]
          date_range = options.delete(:date_range)
          options[:since] = date_range.begin
          options[:until] = date_range.end
        end

        activity_timeline(normalized_context, options.merge(period: :daily))
      end

      def feature_usage_stats(context, options = {})
        normalized_context = normalize_context(context)
        normalized_context.validate!

        events = @storage_adapter.events_for_context(
          normalized_context,
          options.merge(event_type: :feature_usage)
        )

        feature_counts = {}
        events.each do |event|
          feature = event[:metadata]&.dig("feature") || event[:metadata]&.dig(:feature)
          next unless feature

          feature_counts[feature] ||= 0
          feature_counts[feature] += 1
        end

        feature_counts
      end

      def top_features(context, options = {})
        limit = options.delete(:limit) || 10
        stats = feature_usage_stats(context, options)
        stats.sort_by { |_feature, count| -count }.first(limit).to_h
      end

      def funnels
        @funnels ||= Funnels.new(@storage_adapter)
      end

      def cohorts
        @cohorts ||= Cohorts.new(@storage_adapter)
      end

      def retention
        @retention ||= Retention.new(@storage_adapter)
      end

      def geographic
        @geographic ||= Geographic.new(storage_adapter: @storage_adapter)
      end

      def referrer
        @referrer ||= Referrer.new(storage_adapter: @storage_adapter)
      end

      private

      def normalize_context(context)
        return context if context.is_a?(Context)
        Context.new(context)
      end

      def date_from_event(event)
        created_at = event[:created_at] || event["created_at"]
        return nil unless created_at

        if created_at.is_a?(String)
          created_at = Time.parse(created_at)
        elsif created_at.is_a?(Time)
          created_at = created_at
        end

        created_at.to_date if created_at.respond_to?(:to_date)
      rescue
        nil
      end

      def group_by_hour(events)
        events.group_by do |event|
          created_at = event[:created_at] || event["created_at"]
          next nil unless created_at
          time = created_at.is_a?(Time) ? created_at : Time.parse(created_at.to_s)
          time.beginning_of_hour
        end.compact
      end

      def group_by_day(events)
        events.group_by { |event| date_from_event(event) }.compact
      end

      def group_by_week(events)
        events.group_by do |event|
          date = date_from_event(event)
          date&.beginning_of_week if date
        end.compact
      end

      def group_by_month(events)
        events.group_by do |event|
          date = date_from_event(event)
          date&.beginning_of_month if date
        end.compact
      end

      def feature_count(context, options = {})
        stats = feature_usage_stats(context, options)
        stats.keys.count
      end
    end
  end
end

