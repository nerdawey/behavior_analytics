# frozen_string_literal: true

module BehaviorAnalytics
  module Analytics
    class Geographic
      attr_reader :storage_adapter

      def initialize(storage_adapter:)
        @storage_adapter = storage_adapter
      end

      def country_breakdown(context, options = {})
        return [] unless storage_adapter.respond_to?(:query_visits)
        
        visits = storage_adapter.query_visits(context, options)
        visits.group_by { |v| v[:country] }
              .map { |country, visits| { country: country, count: visits.size } }
              .sort_by { |r| -r[:count] }
      end

      def city_breakdown(context, options = {})
        return [] unless storage_adapter.respond_to?(:query_visits)
        
        visits = storage_adapter.query_visits(context, options)
        visits.group_by { |v| v[:city] }
              .map { |city, visits| { city: city, count: visits.size } }
              .sort_by { |r| -r[:count] }
      end

      def country_city_breakdown(context, options = {})
        return [] unless storage_adapter.respond_to?(:query_visits)
        
        visits = storage_adapter.query_visits(context, options)
        visits.group_by { |v| [v[:country], v[:city]] }
              .map { |(country, city), visits| { country: country, city: city, count: visits.size } }
              .sort_by { |r| -r[:count] }
      end

      def device_breakdown(context, options = {})
        return [] unless storage_adapter.respond_to?(:query_visits)
        
        visits = storage_adapter.query_visits(context, options)
        visits.group_by { |v| v[:device_type] }
              .map { |device, visits| { device: device, count: visits.size } }
              .sort_by { |r| -r[:count] }
      end

      def browser_breakdown(context, options = {})
        return [] unless storage_adapter.respond_to?(:query_visits)
        
        visits = storage_adapter.query_visits(context, options)
        visits.group_by { |v| v[:browser] }
              .map { |browser, visits| { browser: browser, count: visits.size } }
              .sort_by { |r| -r[:count] }
      end
    end
  end
end

