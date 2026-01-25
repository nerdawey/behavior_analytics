# frozen_string_literal: true

module BehaviorAnalytics
  class Context
    attr_accessor :tenant_id, :user_id, :user_type, :filters

    def initialize(attributes = {})
      # Only use default_tenant_id if explicitly configured and no tenant_id provided
      # This allows tracking without tenant_id for non-multi-tenant systems
      @tenant_id = attributes[:tenant_id] || attributes[:tenant]
      @tenant_id ||= default_tenant_id if use_default_tenant?
      
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
      # Context is valid if it has at least one identifier (tenant_id, user_id, or both)
      # This supports different business cases:
      # - Multi-tenant: tenant_id required
      # - Single-tenant: user_id sufficient
      # - API-only tracking: tenant_id or user_id optional
      has_tenant? || has_user? || has_any_identifier?
    end

    def has_tenant?
      !tenant_id.nil? && !tenant_id.to_s.empty?
    end

    def has_user?
      !user_id.nil? && !user_id.to_s.empty?
    end

    def has_any_identifier?
      # Check if filters contain any identifying information
      filters.is_a?(Hash) && !filters.empty?
    end

    def validate!
      unless valid?
        raise Error, "Context must have at least one identifier (tenant_id, user_id, or filters). " \
                     "For single-tenant systems, set default_tenant_id in configuration or provide user_id."
      end
    end

    private

    def default_tenant_id
      BehaviorAnalytics.configuration.default_tenant_id
    end

    def use_default_tenant?
      # Only use default tenant if it's explicitly set (not nil)
      default_tenant_id && !default_tenant_id.to_s.empty?
    end
  end
end

