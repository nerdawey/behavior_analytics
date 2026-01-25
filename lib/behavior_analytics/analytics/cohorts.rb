# frozen_string_literal: true

require "set"

module BehaviorAnalytics
  module Analytics
    class Cohorts
      def initialize(storage_adapter)
        @storage_adapter = storage_adapter
      end

      def create_cohort(context, cohort_definition, options = {})
        context.validate!
        
        date_range = options[:date_range] || (options[:since]..options[:until])
        since = date_range.begin || options[:since]
        until_date = date_range.end || options[:until]
        
        all_events = @storage_adapter.events_for_context(
          context,
          since: since,
          until: until_date
        )
        
        # Group users by cohort definition
        cohort_key = cohort_definition[:key] || :created_at
        cohort_period = cohort_definition[:period] || :month
        
        cohorts = {}
        
        all_events.each do |event|
          cohort_date = extract_cohort_date(event, cohort_key, cohort_period)
          cohort_id = cohort_date.strftime(cohort_format(cohort_period))
          
          cohorts[cohort_id] ||= {
            cohort_id: cohort_id,
            cohort_date: cohort_date,
            users: Set.new,
            events: []
          }
          
          cohorts[cohort_id][:users] << event[:user_id] if event[:user_id]
          cohorts[cohort_id][:events] << event
        end
        
        cohorts.values.map do |cohort|
          {
            cohort_id: cohort[:cohort_id],
            cohort_date: cohort[:cohort_date],
            user_count: cohort[:users].size,
            event_count: cohort[:events].size
          }
        end
      end

      def retention_analysis(context, cohorts, options = {})
        context.validate!
        
        period = options[:period] || :day
        periods_to_analyze = options[:periods] || 30
        
        retention_data = {}
        
        cohorts.each do |cohort|
          cohort_id = cohort[:cohort_id] || cohort[:cohort_date]
          cohort_date = cohort[:cohort_date] || parse_cohort_date(cohort_id)
          
          # Get users in this cohort
          cohort_users = get_cohort_users(context, cohort_date, period)
          
          # Calculate retention for each period
          retention_curve = []
          
          (0..periods_to_analyze).each do |period_offset|
            period_date = cohort_date + period_offset.send(period)
            
            active_users = get_active_users(context, cohort_users, period_date, period)
            retention_rate = cohort_users.empty? ? 0.0 : (active_users.size.to_f / cohort_users.size) * 100
            
            retention_curve << {
              period: period_offset,
              date: period_date,
              active_users: active_users.size,
              retention_rate: retention_rate.round(2)
            }
          end
          
          retention_data[cohort_id] = {
            cohort_id: cohort_id,
            cohort_date: cohort_date,
            cohort_size: cohort_users.size,
            retention_curve: retention_curve
          }
        end
        
        retention_data
      end

      def compare_cohorts(context, cohort_ids, options = {})
        context.validate!
        
        cohorts_data = cohort_ids.map do |cohort_id|
          retention_analysis(context, [{ cohort_id: cohort_id }], options)
        end
        
        # Compare retention rates across cohorts
        comparison = {}
        
        max_periods = cohorts_data.map { |c| c.values.first[:retention_curve].size }.max || 0
        
        (0...max_periods).each do |period|
          period_comparison = {
            period: period,
            cohorts: {}
          }
          
          cohorts_data.each do |cohort_data|
            cohort_id = cohort_data.keys.first
            retention_curve = cohort_data[cohort_id][:retention_curve]
            
            if retention_curve[period]
              period_comparison[:cohorts][cohort_id] = {
                retention_rate: retention_curve[period][:retention_rate],
                active_users: retention_curve[period][:active_users]
              }
            end
          end
          
          comparison[period] = period_comparison
        end
        
        comparison
      end

      private

      def extract_cohort_date(event, key, period)
        date_value = event[key.to_sym] || event[key.to_s]
        date = case date_value
        when Time
          date_value
        when String
          Time.parse(date_value)
        else
          Time.parse(event[:created_at].to_s)
        end
        
        normalize_to_period(date, period)
      end

      def normalize_to_period(date, period)
        case period
        when :day
          date.to_date
        when :week
          date.to_date.beginning_of_week
        when :month
          date.to_date.beginning_of_month
        when :year
          date.to_date.beginning_of_year
        else
          date.to_date
        end
      end

      def cohort_format(period)
        case period
        when :day
          "%Y-%m-%d"
        when :week
          "%Y-W%V"
        when :month
          "%Y-%m"
        when :year
          "%Y"
        else
          "%Y-%m-%d"
        end
      end

      def parse_cohort_date(cohort_id)
        # Try to parse various formats
        Time.parse(cohort_id.to_s)
      rescue
        Time.now
      end

      def get_cohort_users(context, cohort_date, period)
        # Get all users who had their first event in this cohort period
        since = cohort_date
        until_date = case period
        when :day
          since + 1.day
        when :week
          since + 1.week
        when :month
          since + 1.month
        when :year
          since + 1.year
        else
          since + 1.day
        end
        
        events = @storage_adapter.events_for_context(
          context,
          since: since,
          until: until_date
        )
        
        # Get unique users
        events.map { |e| e[:user_id] }.compact.uniq
      end

      def get_active_users(context, cohort_users, period_date, period)
        # Get users who were active in this period
        since = period_date
        until_date = case period
        when :day
          since + 1.day
        when :week
          since + 1.week
        when :month
          since + 1.month
        when :year
          since + 1.year
        else
          since + 1.day
        end
        
        events = @storage_adapter.events_for_context(
          context,
          since: since,
          until: until_date
        )
        
        active_user_ids = events.map { |e| e[:user_id] }.compact.uniq
        cohort_users & active_user_ids
      end
    end
  end
end

