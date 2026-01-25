# frozen_string_literal: true

module BehaviorAnalytics
  module Reporting
    class Generator
      def initialize(storage_adapter)
        @storage_adapter = storage_adapter
        @analytics = Analytics::Engine.new(storage_adapter)
      end

      def generate_report(context, report_type, options = {})
        context.validate!

        case report_type.to_sym
        when :summary
          generate_summary_report(context, options)
        when :activity
          generate_activity_report(context, options)
        when :engagement
          generate_engagement_report(context, options)
        when :feature_usage
          generate_feature_usage_report(context, options)
        else
          raise Error, "Unknown report type: #{report_type}"
        end
      end

      def schedule_report(context, report_type, schedule, options = {})
        # This would integrate with a job scheduler
        # For now, return a report configuration
        {
          context: context.to_h,
          report_type: report_type,
          schedule: schedule,
          options: options,
          created_at: Time.now
        }
      end

      private

      def generate_summary_report(context, options)
        date_range = options[:date_range] || (options[:since]..options[:until])
        
        {
          report_type: "summary",
          generated_at: Time.now,
          context: context.to_h,
          date_range: {
            since: date_range.begin,
            until: date_range.end
          },
          metrics: {
            total_events: @analytics.event_count(context, since: date_range.begin, until: date_range.end),
            unique_users: @analytics.unique_users(context, since: date_range.begin, until: date_range.end),
            active_days: @analytics.active_days(context, since: date_range.begin, until: date_range.end),
            engagement_score: @analytics.engagement_score(context, since: date_range.begin, until: date_range.end)
          }
        }
      end

      def generate_activity_report(context, options)
        date_range = options[:date_range] || (options[:since]..options[:until])
        period = options[:period] || :daily

        {
          report_type: "activity",
          generated_at: Time.now,
          context: context.to_h,
          date_range: {
            since: date_range.begin,
            until: date_range.end
          },
          activity_timeline: @analytics.activity_timeline(context, {
            since: date_range.begin,
            until: date_range.end,
            period: period
          })
        }
      end

      def generate_engagement_report(context, options)
        date_range = options[:date_range] || (options[:since]..options[:until])

        {
          report_type: "engagement",
          generated_at: Time.now,
          context: context.to_h,
          date_range: {
            since: date_range.begin,
            until: date_range.end
          },
          engagement_score: @analytics.engagement_score(context, since: date_range.begin, until: date_range.end),
          breakdown: {
            total_events: @analytics.event_count(context, since: date_range.begin, until: date_range.end),
            unique_users: @analytics.unique_users(context, since: date_range.begin, until: date_range.end),
            active_days: @analytics.active_days(context, since: date_range.begin, until: date_range.end),
            feature_diversity: @analytics.top_features(context, since: date_range.begin, until: date_range.end).keys.size
          }
        }
      end

      def generate_feature_usage_report(context, options)
        date_range = options[:date_range] || (options[:since]..options[:until])

        {
          report_type: "feature_usage",
          generated_at: Time.now,
          context: context.to_h,
          date_range: {
            since: date_range.begin,
            until: date_range.end
          },
          feature_stats: @analytics.feature_usage_stats(context, since: date_range.begin, until: date_range.end),
          top_features: @analytics.top_features(context, {
            since: date_range.begin,
            until: date_range.end,
            limit: options[:limit] || 10
          })
        }
      end
    end
  end
end

