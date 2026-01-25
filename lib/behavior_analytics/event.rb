# frozen_string_literal: true

require "securerandom"

module BehaviorAnalytics
  class Event
    EVENT_TYPES = %i[api_call feature_usage custom].freeze

    attr_accessor :id, :tenant_id, :user_id, :user_type, :event_name, :event_type,
                  :metadata, :session_id, :ip, :user_agent, :duration_ms, :created_at,
                  :visit_id, :visitor_id

    def initialize(attributes = {})
      @id = attributes[:id] || SecureRandom.uuid
      @tenant_id = attributes[:tenant_id]
      @user_id = attributes[:user_id]
      @user_type = attributes[:user_type]
      @event_name = attributes[:event_name]
      @event_type = attributes[:event_type] || :custom
      @metadata = attributes[:metadata] || {}
      @session_id = attributes[:session_id]
      @ip = attributes[:ip]
      @user_agent = attributes[:user_agent]
      @duration_ms = attributes[:duration_ms]
      @visit_id = attributes[:visit_id]
      @visitor_id = attributes[:visitor_id]
      @created_at = attributes[:created_at] || Time.now

      validate!
    end

    def to_h
      {
        id: id,
        tenant_id: tenant_id,
        user_id: user_id,
        user_type: user_type,
        event_name: event_name,
        event_type: event_type,
        metadata: metadata,
        session_id: session_id,
        ip: ip,
        user_agent: user_agent,
        duration_ms: duration_ms,
        visit_id: visit_id,
        visitor_id: visitor_id,
        created_at: created_at
      }
    end

    private

    def validate!
      # tenant_id is optional - events can be tracked without tenant for non-multi-tenant systems
      # At least one identifier should be present (tenant_id, user_id, or session_id)
      has_identifier = (!tenant_id.nil? && !tenant_id.to_s.empty?) ||
                       (!user_id.nil? && !user_id.to_s.empty?) ||
                       (!session_id.nil? && !session_id.to_s.empty?)
      
      raise Error, "Event must have at least one identifier (tenant_id, user_id, or session_id)" unless has_identifier
      raise Error, "event_name is required" if event_name.nil? || event_name.empty?
      raise Error, "event_type must be one of: #{EVENT_TYPES.join(', ')}" unless EVENT_TYPES.include?(event_type)
    end
  end
end

