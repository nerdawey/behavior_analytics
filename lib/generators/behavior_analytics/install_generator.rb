# frozen_string_literal: true

begin
  require "rails/generators"
  require "rails/generators/active_record"
rescue LoadError
  raise LoadError, "Rails generators require Rails. Please add 'rails' to your Gemfile."
end

module BehaviorAnalytics
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration

      source_root File.expand_path("../templates", __FILE__)

      def create_migration
        migration_template "create_behavior_events.rb",
                           "db/migrate/create_behavior_events.rb"
      end

      def create_initializer
        create_file "config/initializers/behavior_analytics.rb", <<~RUBY
          BehaviorAnalytics.configure do |config|
            config.storage_adapter = BehaviorAnalytics::Storage::ActiveRecordAdapter.new(
              model_class: BehaviorAnalyticsEvent
            )

            config.batch_size = 100
            config.flush_interval = 300

            config.context_resolver = ->(request) {
              {
                tenant_id: current_tenant&.id,
                user_id: current_user&.id,
                user_type: current_user&.account_type
              }
            }

            config.scoring_weights = {
              activity: 0.4,
              unique_users: 0.3,
              feature_diversity: 0.2,
              time_in_trial: 0.1
            }
          end
        RUBY
      end

      def create_model
        create_file "app/models/behavior_analytics_event.rb", <<~RUBY
          class BehaviorAnalyticsEvent < ApplicationRecord
            self.table_name = "behavior_events"

            scope :for_tenant, ->(tenant_id) { where(tenant_id: tenant_id) }
            scope :for_user, ->(user_id) { where(user_id: user_id) }
            scope :for_user_type, ->(user_type) { where(user_type: user_type) }
            scope :with_event_name, ->(name) { where(event_name: name) }
            scope :with_event_type, ->(type) { where(event_type: type.to_s) }
            scope :since, ->(date) { where("created_at >= ?", date) }
            scope :until, ->(date) { where("created_at <= ?", date) }

            def to_h
              {
                id: id,
                tenant_id: tenant_id,
                user_id: user_id,
                user_type: user_type,
                event_name: event_name,
                event_type: event_type.to_sym,
                metadata: metadata || {},
                session_id: session_id,
                ip: ip,
                user_agent: user_agent,
                duration_ms: duration_ms,
                created_at: created_at
              }
            end
          end
        RUBY
      end
    end
  end
end

