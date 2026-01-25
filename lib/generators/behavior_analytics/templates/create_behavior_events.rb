# frozen_string_literal: true

class CreateBehaviorEvents < ActiveRecord::Migration[<%= ActiveRecord::Migration.current_version %>]
  def change
    create_table :behavior_events do |t|
      t.string :tenant_id  # Nullable to support single-tenant and API-only tracking
      t.string :user_id
      t.string :user_type
      t.string :event_name, null: false
      t.string :event_type, null: false
      t.jsonb :metadata, default: {}
      t.string :session_id
      t.string :ip
      t.string :user_agent
      t.integer :duration_ms
      t.datetime :created_at, null: false
    end

    add_index :behavior_events, :tenant_id  # Index even if nullable for multi-tenant queries
    add_index :behavior_events, :user_id
    add_index :behavior_events, :user_type
    add_index :behavior_events, :event_name
    add_index :behavior_events, :event_type
    add_index :behavior_events, :session_id
    add_index :behavior_events, :created_at
    add_index :behavior_events, [:tenant_id, :created_at]
    add_index :behavior_events, [:tenant_id, :user_id, :created_at]
    add_index :behavior_events, [:tenant_id, :event_name, :created_at]
  end
end

