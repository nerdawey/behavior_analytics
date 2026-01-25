# frozen_string_literal: true

module BehaviorAnalytics
  module Detection
    class Geolocation
      def initialize(strategy: :simple)
        @strategy = strategy
      end

      def detect(ip_address)
        return {} unless ip_address
        return {} if ip_address == "127.0.0.1" || ip_address == "::1" || ip_address.start_with?("192.168.") || ip_address.start_with?("10.")

        case @strategy
        when :geocoder
          detect_with_geocoder(ip_address)
        when :maxmind
          detect_with_maxmind(ip_address)
        else
          detect_simple(ip_address)
        end
      end

      private

      def detect_simple(ip_address)
        # Simple detection - returns empty for now
        # In production, you'd want to use a proper geolocation service
        {}
      end

      def detect_with_geocoder(ip_address)
        begin
          require "geocoder"
          result = Geocoder.search(ip_address).first
          return {} unless result

          {
            country: result.country,
            country_code: result.country_code,
            city: result.city,
            region: result.region,
            latitude: result.latitude,
            longitude: result.longitude,
            timezone: result.data&.dig("timezone")
          }.compact
        rescue LoadError, StandardError => e
          BehaviorAnalytics.configuration.log_error(e, context: { ip: ip_address }) if BehaviorAnalytics.configuration.debug_mode
          {}
        end
      end

      def detect_with_maxmind(ip_address)
        begin
          require "maxminddb"
          # This would require MaxMind GeoIP2 database
          # For now, return empty - users can implement their own
          {}
        rescue LoadError, StandardError => e
          BehaviorAnalytics.configuration.log_error(e, context: { ip: ip_address }) if BehaviorAnalytics.configuration.debug_mode
          {}
        end
      end
    end
  end
end

