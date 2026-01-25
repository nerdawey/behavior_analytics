# frozen_string_literal: true

module BehaviorAnalytics
  module Visits
    class Visit
      attr_accessor :visit_token, :visitor_token, :tenant_id, :user_id, :ip, :user_agent,
                    :referrer, :landing_page, :browser, :os, :device_type, :country, :city,
                    :utm_source, :utm_medium, :utm_campaign, :utm_term, :utm_content,
                    :referring_domain, :search_keyword, :started_at, :ended_at, :created_at, :updated_at

      def initialize(attributes = {})
        @visit_token = attributes[:visit_token] || SecureRandom.hex(16)
        @visitor_token = attributes[:visitor_token] || SecureRandom.hex(16)
        @tenant_id = attributes[:tenant_id]
        @user_id = attributes[:user_id]
        @ip = attributes[:ip]
        @user_agent = attributes[:user_agent]
        @referrer = attributes[:referrer]
        @landing_page = attributes[:landing_page]
        @browser = attributes[:browser]
        @os = attributes[:os]
        @device_type = attributes[:device_type]
        @country = attributes[:country]
        @city = attributes[:city]
        @utm_source = attributes[:utm_source]
        @utm_medium = attributes[:utm_medium]
        @utm_campaign = attributes[:utm_campaign]
        @utm_term = attributes[:utm_term]
        @utm_content = attributes[:utm_content]
        @referring_domain = attributes[:referring_domain]
        @search_keyword = attributes[:search_keyword]
        @started_at = attributes[:started_at] || Time.now
        @ended_at = attributes[:ended_at]
        @created_at = attributes[:created_at] || Time.now
        @updated_at = attributes[:updated_at] || Time.now
      end

      def to_h
        {
          visit_token: visit_token,
          visitor_token: visitor_token,
          tenant_id: tenant_id,
          user_id: user_id,
          ip: ip,
          user_agent: user_agent,
          referrer: referrer,
          landing_page: landing_page,
          browser: browser,
          os: os,
          device_type: device_type,
          country: country,
          city: city,
          utm_source: utm_source,
          utm_medium: utm_medium,
          utm_campaign: utm_campaign,
          utm_term: utm_term,
          utm_content: utm_content,
          referring_domain: referring_domain,
          search_keyword: search_keyword,
          started_at: started_at,
          ended_at: ended_at,
          created_at: created_at,
          updated_at: updated_at
        }.compact
      end

      def duration_seconds
        return nil unless ended_at
        (ended_at - started_at).to_i
      end

      def active?
        ended_at.nil?
      end

      def expired?(inactivity_duration = 30.minutes)
        return false unless active?
        (Time.now - started_at) > inactivity_duration
      end

      def end!
        @ended_at = Time.now
        @updated_at = Time.now
      end
    end
  end
end

