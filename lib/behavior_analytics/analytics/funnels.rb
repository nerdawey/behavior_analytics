# frozen_string_literal: true

module BehaviorAnalytics
  module Analytics
    class Funnels
      def initialize(storage_adapter)
        @storage_adapter = storage_adapter
      end

      def analyze_funnel(context, steps, options = {})
        context.validate!
        
        date_range = options[:date_range] || (options[:since]..options[:until])
        since = date_range.begin || options[:since]
        until_date = date_range.end || options[:until]
        
        # Get all events for the context in the date range
        all_events = @storage_adapter.events_for_context(
          context,
          since: since,
          until: until_date
        )
        
        # Group events by user
        user_events = group_events_by_user(all_events)
        
        # Analyze each step
        funnel_results = steps.map.with_index do |step, index|
          step_name = step.is_a?(Hash) ? step[:name] : step.to_s
          step_condition = step.is_a?(Hash) ? step[:condition] : ->(e) { e[:event_name] == step }
          
          users_at_step = user_events.select do |user_id, events|
            events.any? { |e| evaluate_condition(e, step_condition) }
          end
          
          {
            step: step_name,
            step_index: index,
            users: users_at_step.keys.count,
            events: all_events.count { |e| evaluate_condition(e, step_condition) }
          }
        end
        
        # Calculate drop-off rates
        funnel_results.each_with_index do |step_result, index|
          if index == 0
            step_result[:drop_off_rate] = 0.0
            step_result[:conversion_rate] = 100.0
          else
            previous_users = funnel_results[index - 1][:users]
            current_users = step_result[:users]
            
            if previous_users > 0
              step_result[:drop_off_rate] = ((previous_users - current_users).to_f / previous_users) * 100
              step_result[:conversion_rate] = (current_users.to_f / previous_users) * 100
            else
              step_result[:drop_off_rate] = 100.0
              step_result[:conversion_rate] = 0.0
            end
          end
        end
        
        {
          steps: funnel_results,
          total_users: funnel_results.first[:users],
          completed_users: funnel_results.last[:users],
          overall_conversion_rate: calculate_overall_conversion(funnel_results)
        }
      end

      def time_to_conversion(context, start_event, end_event, options = {})
        context.validate!
        
        date_range = options[:date_range] || (options[:since]..options[:until])
        since = date_range.begin || options[:since]
        until_date = date_range.end || options[:until]
        
        all_events = @storage_adapter.events_for_context(
          context,
          since: since,
          until: until_date
        )
        
        user_events = group_events_by_user(all_events)
        
        conversion_times = []
        
        user_events.each do |user_id, events|
          sorted_events = events.sort_by { |e| parse_time(e[:created_at]) }
          
          start_index = sorted_events.index { |e| matches_event(e, start_event) }
          next unless start_index
          
          end_index = sorted_events[start_index..-1].index { |e| matches_event(e, end_event) }
          next unless end_index
          
          start_time = parse_time(sorted_events[start_index][:created_at])
          end_time = parse_time(sorted_events[start_index + end_index][:created_at])
          
          conversion_times << (end_time - start_time)
        end
        
        return {} if conversion_times.empty?
        
        {
          average_seconds: conversion_times.sum / conversion_times.size,
          median_seconds: median(conversion_times),
          min_seconds: conversion_times.min,
          max_seconds: conversion_times.max,
          count: conversion_times.size
        }
      end

      private

      def group_events_by_user(events)
        events.group_by { |e| e[:user_id] }.reject { |k, _| k.nil? }
      end

      def evaluate_condition(event, condition)
        case condition
        when Proc
          condition.call(event)
        when String, Symbol
          event[:event_name] == condition.to_s
        when Hash
          condition.all? { |key, value| event[key.to_sym] == value || event[key.to_s] == value }
        else
          false
        end
      end

      def matches_event(event, event_spec)
        case event_spec
        when String, Symbol
          event[:event_name] == event_spec.to_s
        when Hash
          event_spec.all? { |key, value| event[key.to_sym] == value || event[key.to_s] == value }
        when Proc
          event_spec.call(event)
        else
          false
        end
      end

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

      def median(array)
        sorted = array.sort
        len = sorted.length
        (sorted[(len - 1) / 2] + sorted[len / 2]) / 2.0
      end

      def calculate_overall_conversion(funnel_results)
        return 0.0 if funnel_results.empty?
        
        first_step = funnel_results.first
        last_step = funnel_results.last
        
        return 0.0 if first_step[:users] == 0
        
        (last_step[:users].to_f / first_step[:users]) * 100
      end
    end
  end
end

