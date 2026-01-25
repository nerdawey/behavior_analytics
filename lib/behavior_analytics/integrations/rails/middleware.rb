# frozen_string_literal: true

module BehaviorAnalytics
  module Integrations
    module Rails
      class Middleware
        def initialize(app)
          @app = app
        end

        def call(env)
          start_time = Time.now
          status, headers, response = @app.call(env)
          
          # Track request if enabled
          if should_track_request?(env)
            track_request(env, status, start_time)
          end
          
          [status, headers, response]
        end

        private

        def should_track_request?(env)
          return false unless BehaviorAnalytics.configuration.storage_adapter
          return false unless BehaviorAnalytics.configuration.track_middleware_requests

          path = env["PATH_INFO"]
          return false if path_blacklisted?(path)
          return false if path_not_whitelisted?(path)

          true
        end

        def path_blacklisted?(path)
          blacklist = BehaviorAnalytics.configuration.tracking_blacklist || []
          return false if blacklist.empty?

          blacklist.any? { |pattern| matches_pattern?(path, pattern) }
        end

        def path_not_whitelisted?(path)
          whitelist = BehaviorAnalytics.configuration.tracking_whitelist
          return false unless whitelist && !whitelist.empty?

          !whitelist.any? { |pattern| matches_pattern?(path, pattern) }
        end

        def matches_pattern?(path, pattern)
          case pattern
          when Regexp
            pattern.match?(path)
          when String
            path.include?(pattern) || File.fnmatch?(pattern, path)
          else
            false
          end
        end

        def track_request(env, status, start_time)
          duration_ms = ((Time.now - start_time) * 1000).to_i
          
          # Try to extract context from env
          context = extract_context_from_env(env)
          return unless context&.valid?

          tracker = BehaviorAnalytics.create_tracker
          tracker.track_api_call(
            context: context,
            method: env["REQUEST_METHOD"],
            path: env["PATH_INFO"],
            status_code: status,
            duration_ms: duration_ms,
            ip: env["REMOTE_ADDR"],
            user_agent: env["HTTP_USER_AGENT"]
          )
        rescue StandardError => e
          # Don't let tracking errors break the request
          if defined?(Rails) && Rails.logger
            Rails.logger.error("BehaviorAnalytics: Middleware tracking error: #{e.message}")
          end
        end

        def extract_context_from_env(env)
          # Try to get context from request store or session
          if defined?(ActionDispatch::Request)
            request = ActionDispatch::Request.new(env)
            # This would need to be customized based on your app's context resolution
            nil
          else
            nil
          end
        end
      end
    end
  end
end

