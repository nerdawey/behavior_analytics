# frozen_string_literal: true

module BehaviorAnalytics
  module Identification
    class UserResolver
      attr_reader :visit_manager

      def initialize(visit_manager:)
        @visit_manager = visit_manager
      end

      def identify_user(user_id, visitor_token: nil, request: nil)
        return unless user_id

        # If visitor_token is provided, link all anonymous visits to this user
        if visitor_token
          visit_manager.link_user_to_visits(visitor_token, user_id)
        elsif request
          # Try to get visitor token from request
          visitor_token = get_visitor_token_from_request(request)
          visit_manager.link_user_to_visits(visitor_token, user_id) if visitor_token
        end
      end

      def merge_visits(visitor_token, user_id)
        visit_manager.link_user_to_visits(visitor_token, user_id)
      end

      def get_visitor_token_from_request(request)
        # Try cookie first
        if request.respond_to?(:cookies)
          token = request.cookies["behavior_visitor_token"]
          return token if token && !token.empty?
        end

        # Try header
        if request.respond_to?(:headers)
          token = request.headers["X-Visitor-Token"]
          return token if token && !token.empty?
        end

        nil
      end

      def get_user_visits(user_id, limit: 100)
        visit_manager.find_visits_by_user(user_id, limit: limit)
      end

      def get_visitor_visits(visitor_token, limit: 100)
        visit_manager.find_visits_by_visitor(visitor_token, limit: limit)
      end
    end
  end
end

