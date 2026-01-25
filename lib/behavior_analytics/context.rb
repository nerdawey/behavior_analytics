# frozen_string_literal: true

module BehaviorAnalytics
  class Context
    attr_accessor :tenant_id, :user_id, :user_type, :filters

    def initialize(attributes = {})
      @tenant_id = attributes[:tenant_id] || attributes[:tenant] || default_tenant_id
      @user_id = attributes[:user_id] || attributes[:user]
      @user_type = attributes[:user_type]
      @filters = attributes[:filters] || {}
    end

    def to_h
      {
        tenant_id: tenant_id,
        user_id: user_id,
        user_type: user_type,
        filters: filters
      }.compact
    end

    def valid?
      !tenant_id.nil? && !tenant_id.empty?
    end

    def validate!
      raise Error, "tenant_id is required in context. Set a default_tenant_id in configuration for single-tenant systems." unless valid?
    end

    private

    def default_tenant_id
      BehaviorAnalytics.configuration.default_tenant_id
    end
  end
end

