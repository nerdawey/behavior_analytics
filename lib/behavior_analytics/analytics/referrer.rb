# frozen_string_literal: true

require "uri"

module BehaviorAnalytics
  module Analytics
    class Referrer
      attr_reader :storage_adapter

      def initialize(storage_adapter:)
        @storage_adapter = storage_adapter
      end

      def source_breakdown(context, options = {})
        return [] unless storage_adapter.respond_to?(:query_visits)
        
        visits = storage_adapter.query_visits(context, options)
        visits.group_by { |v| extract_source(v[:referrer]) }
              .map { |source, visits| { source: source || "direct", count: visits.size } }
              .sort_by { |r| -r[:count] }
      end

      def utm_source_breakdown(context, options = {})
        return [] unless storage_adapter.respond_to?(:query_visits)
        
        visits = storage_adapter.query_visits(context, options)
        visits.group_by { |v| v[:utm_source] }
              .map { |source, visits| { utm_source: source || "none", count: visits.size } }
              .sort_by { |r| -r[:count] }
      end

      def utm_campaign_breakdown(context, options = {})
        return [] unless storage_adapter.respond_to?(:query_visits)
        
        visits = storage_adapter.query_visits(context, options)
        visits.group_by { |v| v[:utm_campaign] }
              .map { |campaign, visits| { utm_campaign: campaign || "none", count: visits.size } }
              .sort_by { |r| -r[:count] }
      end

      def search_keyword_breakdown(context, options = {})
        return [] unless storage_adapter.respond_to?(:query_visits)
        
        visits = storage_adapter.query_visits(context, options)
        visits.select { |v| v[:search_keyword] }
              .group_by { |v| v[:search_keyword] }
              .map { |keyword, visits| { keyword: keyword, count: visits.size } }
              .sort_by { |r| -r[:count] }
      end

      def referring_domain_breakdown(context, options = {})
        return [] unless storage_adapter.respond_to?(:query_visits)
        
        visits = storage_adapter.query_visits(context, options)
        visits.group_by { |v| v[:referring_domain] }
              .map { |domain, visits| { domain: domain || "direct", count: visits.size } }
              .sort_by { |r| -r[:count] }
      end

      private

      def extract_source(referrer)
        return nil unless referrer
        
        uri = URI.parse(referrer) rescue nil
        return nil unless uri
        
        host = uri.host&.downcase
        return "google" if host&.include?("google")
        return "bing" if host&.include?("bing")
        return "yahoo" if host&.include?("yahoo")
        return "facebook" if host&.include?("facebook")
        return "twitter" if host&.include?("twitter") || host&.include?("x.com")
        return "linkedin" if host&.include?("linkedin")
        return "reddit" if host&.include?("reddit")
        
        host
      end
    end
  end
end

