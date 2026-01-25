# frozen_string_literal: true

module BehaviorAnalytics
  module Analytics
    class Retention
      def initialize(storage_adapter)
        @storage_adapter = storage_adapter
      end

      def calculate_retention(context, options = {})
        context.validate!
        
        period = options[:period] || :day
        periods = options[:periods] || 30
        
        # Get all events for the context
        date_range = options[:date_range] || (options[:since]..options[:until])
        since = date_range.begin || options[:since]
        until_date = date_range.end || options[:until]
        
        all_events = @storage_adapter.events_for_context(
          context,
          since: since,
          until: until_date
        )
        
        # Group events by user and calculate first activity
        user_first_activity = {}
        user_activity_by_period = {}
        
        all_events.each do |event|
          user_id = event[:user_id]
          next unless user_id
          
          event_time = parse_time(event[:created_at])
          period_key = period_key_for_time(event_time, period)
          
          # Track first activity
          unless user_first_activity[user_id]
            user_first_activity[user_id] = {
              first_period: period_key,
              first_date: event_time
            }
          end
          
          # Track activity by period
          user_activity_by_period[user_id] ||= Set.new
          user_activity_by_period[user_id] << period_key
        end
        
        # Calculate retention
        retention_by_period = {}
        
        user_first_activity.each do |user_id, first_activity|
          first_period = first_activity[:first_period]
          user_periods = user_activity_by_period[user_id] || Set.new
          
          (0..periods).each do |offset|
            target_period = offset_period(first_period, offset, period)
            is_active = user_periods.include?(target_period)
            
            retention_by_period[offset] ||= {
              period: offset,
              total_users: 0,
              active_users: 0,
              retention_rate: 0.0
            }
            
            retention_by_period[offset][:total_users] += 1
            retention_by_period[offset][:active_users] += 1 if is_active
          end
        end
        
        # Calculate retention rates
        retention_by_period.values.each do |data|
          if data[:total_users] > 0
            data[:retention_rate] = (data[:active_users].to_f / data[:total_users]) * 100
          end
        end
        
        {
          retention_curve: retention_by_period.values.sort_by { |d| d[:period] },
          total_cohort_size: user_first_activity.size,
          period_type: period
        }
      end

      def calculate_churn(context, options = {})
        context.validate!
        
        period = options[:period] || :day
        lookback_periods = options[:lookback_periods] || 7
        
        # Get recent events
        since = options[:since] || (Time.now - lookback_periods.send(period))
        until_date = options[:until] || Time.now
        
        all_events = @storage_adapter.events_for_context(
          context,
          since: since,
          until: until_date
        )
        
        # Group by user and period
        user_periods = {}
        
        all_events.each do |event|
          user_id = event[:user_id]
          next unless user_id
          
          event_time = parse_time(event[:created_at])
          period_key = period_key_for_time(event_time, period)
          
          user_periods[user_id] ||= Set.new
          user_periods[user_id] << period_key
        end
        
        # Calculate churn (users who were active but stopped)
        current_period = period_key_for_time(until_date, period)
        previous_period = offset_period(current_period, -1, period)
        
        active_in_previous = user_periods.select { |_, periods| periods.include?(previous_period) }.keys
        active_in_current = user_periods.select { |_, periods| periods.include?(current_period) }.keys
        
        churned_users = active_in_previous - active_in_current
        
        {
          churned_users: churned_users.size,
          churned_user_ids: churned_users,
          previous_period_active: active_in_previous.size,
          current_period_active: active_in_current.size,
          churn_rate: active_in_previous.empty? ? 0.0 : (churned_users.size.to_f / active_in_previous.size) * 100
        }
      end

      private

      def parse_time(time_value)
        case time_value
        when Time
          time_value
        when String
          Time.parse(time_value)
        else
          Time.now
        end
      end

      def period_key_for_time(time, period)
        case period
        when :day
          time.to_date.strftime("%Y-%m-%d")
        when :week
          time.to_date.beginning_of_week.strftime("%Y-W%V")
        when :month
          time.to_date.beginning_of_month.strftime("%Y-%m")
        when :year
          time.to_date.beginning_of_year.strftime("%Y")
        else
          time.to_date.strftime("%Y-%m-%d")
        end
      end

      def offset_period(period_key, offset, period)
        # Parse period key and add offset
        base_date = case period
        when :day
          Date.parse(period_key)
        when :week
          year, week = period_key.match(/(\d{4})-W(\d{2})/).captures
          Date.commercial(year.to_i, week.to_i, 1)
        when :month
          Date.parse("#{period_key}-01")
        when :year
          Date.parse("#{period_key}-01-01")
        else
          Date.parse(period_key)
        end
        
        offset_date = base_date + offset.send(period)
        period_key_for_time(offset_date.to_time, period)
      end
    end
  end
end

