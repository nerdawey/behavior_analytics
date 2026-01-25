# frozen_string_literal: true

module BehaviorAnalytics
  module Visits
    class AutoCreator
      attr_reader :manager, :cookie_name

      def initialize(manager:, cookie_name: "behavior_visitor_token")
        @manager = manager
        @cookie_name = cookie_name
      end

      def get_or_create_visit(request:, tenant_id: nil, user_id: nil)
        visitor_token = get_or_create_visitor_token(request)
        
        utm_params = extract_utm_params(request)
        
        manager.find_or_create_visit(
          visitor_token: visitor_token,
          tenant_id: tenant_id,
          user_id: user_id,
          ip: request.ip,
          user_agent: request.user_agent,
          referrer: request.referer,
          landing_page: request.path,
          utm_params: utm_params
        )
      end

      def get_or_create_visitor_token(request)
        # Try to get from cookie
        if request.respond_to?(:cookies)
          token = request.cookies[cookie_name]
          return token if token && !token.empty?
        end

        # Try to get from headers (for API requests)
        if request.respond_to?(:headers)
          token = request.headers["X-Visitor-Token"]
          return token if token && !token.empty?
        end

        # Generate new token
        SecureRandom.hex(16)
      end

      def set_visitor_token_cookie(response, visitor_token)
        return unless response.respond_to?(:set_cookie)
        
        # Set cookie for 2 years
        secure = if defined?(Rails)
          Rails.env.production?
        else
          ENV["RAILS_ENV"] == "production" || ENV["RACK_ENV"] == "production"
        end
        
        response.set_cookie(
          cookie_name,
          value: visitor_token,
          expires: 2.years.from_now,
          httponly: true,
          secure: secure,
          same_site: :lax
        )
      end

      private

      def extract_utm_params(request)
        params = {}
        
        if request.respond_to?(:params)
          params[:utm_source] = request.params["utm_source"]
          params[:utm_medium] = request.params["utm_medium"]
          params[:utm_campaign] = request.params["utm_campaign"]
          params[:utm_term] = request.params["utm_term"]
          params[:utm_content] = request.params["utm_content"]
        end

        params.compact
      end
    end
  end
end

