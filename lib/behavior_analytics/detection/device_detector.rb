# frozen_string_literal: true

module BehaviorAnalytics
  module Detection
    class DeviceDetector
      def initialize(strategy: :simple)
        @strategy = strategy
      end

      def detect(user_agent)
        return {} unless user_agent

        case @strategy
        when :browser
          detect_with_browser_gem(user_agent)
        when :user_agent_parser
          detect_with_user_agent_parser(user_agent)
        else
          detect_simple(user_agent)
        end
      end

      private

      def detect_simple(user_agent)
        ua = user_agent.downcase
        result = {
          browser: detect_browser(ua),
          os: detect_os(ua),
          device_type: detect_device_type(ua)
        }
        result.compact
      end

      def detect_browser(ua)
        return "Chrome" if ua.include?("chrome") && !ua.include?("edg")
        return "Safari" if ua.include?("safari") && !ua.include?("chrome")
        return "Firefox" if ua.include?("firefox")
        return "Edge" if ua.include?("edg")
        return "Opera" if ua.include?("opera") || ua.include?("opr")
        return "Internet Explorer" if ua.include?("msie") || ua.include?("trident")
        "Unknown"
      end

      def detect_os(ua)
        return "iOS" if ua.include?("iphone") || ua.include?("ipad") || ua.include?("ipod")
        return "Android" if ua.include?("android")
        return "Windows" if ua.include?("windows")
        return "Mac OS" if ua.include?("mac os") || ua.include?("macintosh")
        return "Linux" if ua.include?("linux")
        return "Unix" if ua.include?("unix")
        "Unknown"
      end

      def detect_device_type(ua)
        ua_lower = ua.downcase
        return "mobile" if ua_lower.include?("mobile") || ua_lower.include?("iphone") || ua_lower.include?("android")
        return "tablet" if ua_lower.include?("tablet") || ua_lower.include?("ipad")
        return "desktop" if ua_lower.include?("windows") || ua_lower.include?("mac") || ua_lower.include?("linux")
        "unknown"
      end

      def detect_with_browser_gem(user_agent)
        begin
          require "browser"
          browser = Browser.new(user_agent)
          {
            browser: browser.name,
            browser_version: browser.version,
            os: browser.platform.name,
            os_version: browser.platform.version,
            device_type: browser.device.mobile? ? "mobile" : (browser.device.tablet? ? "tablet" : "desktop")
          }
        rescue LoadError, StandardError
          detect_simple(user_agent)
        end
      end

      def detect_with_user_agent_parser(user_agent)
        begin
          require "user_agent_parser"
          parser = UserAgentParser.parse(user_agent)
          {
            browser: parser.family,
            browser_version: parser.version.to_s,
            os: parser.os&.family,
            os_version: parser.os&.version&.to_s,
            device_type: detect_device_type_from_parser(parser)
          }
        rescue LoadError, StandardError
          detect_simple(user_agent)
        end
      end

      def detect_device_type_from_parser(parser)
        device = parser.device
        return "mobile" if device&.family&.downcase&.include?("mobile")
        return "tablet" if device&.family&.downcase&.include?("tablet")
        "desktop"
      end
    end
  end
end

