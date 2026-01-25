# frozen_string_literal: true

require "securerandom"
require "uri"

module BehaviorAnalytics
  module Visits
    class Manager
      attr_reader :storage_adapter, :visit_duration

      def initialize(storage_adapter:, visit_duration: 30.minutes, device_detector: nil, geolocation: nil)
        @storage_adapter = storage_adapter
        @visit_duration = visit_duration
        @device_detector = device_detector
        @geolocation = geolocation
      end

      def find_or_create_visit(visitor_token:, tenant_id: nil, user_id: nil, ip: nil, user_agent: nil, 
                               referrer: nil, landing_page: nil, utm_params: {})
        # Try to find active visit for this visitor
        active_visit = find_active_visit(visitor_token, user_id)
        
        if active_visit && !active_visit.expired?(visit_duration)
          # Update visit if user logged in
          if user_id && active_visit.user_id.nil?
            active_visit.user_id = user_id
            save_visit(active_visit)
          end
          return active_visit
        end

        # Detect device and geolocation if enabled
        device_info = {}
        geo_info = {}
        
        if BehaviorAnalytics.configuration.track_device_info && @device_detector && user_agent
          device_info = @device_detector.detect(user_agent)
        end
        
        if BehaviorAnalytics.configuration.track_geolocation && @geolocation && ip
          geo_info = @geolocation.detect(ip)
        end

        # Create new visit
        visit = Visit.new(
          visitor_token: visitor_token,
          tenant_id: tenant_id || BehaviorAnalytics.configuration.default_tenant_id,
          user_id: user_id,
          ip: ip,
          user_agent: user_agent,
          referrer: referrer,
          landing_page: landing_page || referrer,
          browser: device_info[:browser],
          os: device_info[:os],
          device_type: device_info[:device_type],
          country: geo_info[:country],
          city: geo_info[:city],
          utm_source: utm_params[:utm_source],
          utm_medium: utm_params[:utm_medium],
          utm_campaign: utm_params[:utm_campaign],
          utm_term: utm_params[:utm_term],
          utm_content: utm_params[:utm_content],
          referring_domain: extract_domain(referrer),
          search_keyword: extract_search_keyword(referrer)
        )

        save_visit(visit)
        visit
      end

      def find_active_visit(visitor_token, user_id = nil)
        return nil unless storage_adapter.respond_to?(:find_active_visit)
        
        visit_data = storage_adapter.find_active_visit(visitor_token, user_id, visit_duration)
        return nil unless visit_data

        Visit.new(visit_data)
      end

      def save_visit(visit)
        if storage_adapter.respond_to?(:save_visit)
          storage_adapter.save_visit(visit.to_h)
        end
      end

      def end_visit(visit_token)
        visit = find_visit_by_token(visit_token)
        return unless visit

        visit.end!
        save_visit(visit)
      end

      def find_visit_by_token(visit_token)
        return nil unless storage_adapter.respond_to?(:find_visit_by_token)
        
        visit_data = storage_adapter.find_visit_by_token(visit_token)
        return nil unless visit_data

        Visit.new(visit_data)
      end

      def link_user_to_visits(visitor_token, user_id)
        return unless storage_adapter.respond_to?(:link_user_to_visits)
        
        storage_adapter.link_user_to_visits(visitor_token, user_id)
      end

      def find_visits_by_user(user_id, limit: 100)
        return [] unless storage_adapter.respond_to?(:find_visits_by_user)
        
        visits_data = storage_adapter.find_visits_by_user(user_id, limit: limit)
        visits_data.map { |data| Visit.new(data) }
      end

      def find_visits_by_visitor(visitor_token, limit: 100)
        return [] unless storage_adapter.respond_to?(:find_visits_by_visitor)
        
        visits_data = storage_adapter.find_visits_by_visitor(visitor_token, limit: limit)
        visits_data.map { |data| Visit.new(data) }
      end

      private

      def extract_domain(url)
        return nil unless url
        URI.parse(url).host rescue nil
      end

      def extract_search_keyword(referrer)
        return nil unless referrer
        
        uri = URI.parse(referrer) rescue nil
        return nil unless uri
        
        # Extract from Google, Bing, etc.
        if uri.host&.include?("google")
          params = URI.decode_www_form(uri.query || "").to_h
          params["q"] || params["query"]
        elsif uri.host&.include?("bing")
          params = URI.decode_www_form(uri.query || "").to_h
          params["q"]
        else
          nil
        end
      end
    end
  end
end

