# frozen_string_literal: true

class EnhanceBehaviorEventsV2 < ActiveRecord::Migration[7.0]
  def change
    # Add new columns for faster queries
    add_column :behavior_events, :path, :string unless column_exists?(:behavior_events, :path)
    add_column :behavior_events, :method, :string unless column_exists?(:behavior_events, :method)
    add_column :behavior_events, :status_code, :integer unless column_exists?(:behavior_events, :status_code)
    add_column :behavior_events, :correlation_id, :string unless column_exists?(:behavior_events, :correlation_id)
    add_column :behavior_events, :parent_event_id, :string unless column_exists?(:behavior_events, :parent_event_id)
    add_column :behavior_events, :tags, :string, array: true, default: [] unless column_exists?(:behavior_events, :tags)

    # Add indexes for new columns
    add_index :behavior_events, :path unless index_exists?(:behavior_events, :path)
    add_index :behavior_events, :method unless index_exists?(:behavior_events, :method)
    add_index :behavior_events, :status_code unless index_exists?(:behavior_events, :status_code)
    add_index :behavior_events, :correlation_id unless index_exists?(:behavior_events, :correlation_id)
    add_index :behavior_events, :parent_event_id unless index_exists?(:behavior_events, :parent_event_id)
    add_index :behavior_events, :tags, using: :gin unless index_exists?(:behavior_events, :tags)

    # Add composite indexes for common query patterns
    add_index :behavior_events, [:tenant_id, :path, :created_at], 
              name: "index_behavior_events_on_tenant_path_created" unless 
              index_exists?(:behavior_events, [:tenant_id, :path, :created_at], 
                           name: "index_behavior_events_on_tenant_path_created")
    
    add_index :behavior_events, [:tenant_id, :user_type, :created_at],
              name: "index_behavior_events_on_tenant_user_type_created" unless
              index_exists?(:behavior_events, [:tenant_id, :user_type, :created_at],
                           name: "index_behavior_events_on_tenant_user_type_created")
    
    add_index :behavior_events, [:tenant_id, :event_type, :created_at],
              name: "index_behavior_events_on_tenant_event_type_created" unless
              index_exists?(:behavior_events, [:tenant_id, :event_type, :created_at],
                           name: "index_behavior_events_on_tenant_event_type_created")

    # Add GIN index on metadata JSONB for faster queries
    if column_exists?(:behavior_events, :metadata)
      execute <<-SQL
        CREATE INDEX IF NOT EXISTS index_behavior_events_on_metadata_gin 
        ON behavior_events USING gin (metadata);
      SQL
    end
  end
end

