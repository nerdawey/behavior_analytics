# frozen_string_literal: true

class AddVisitFieldsToEvents < ActiveRecord::Migration[7.0]
  def change
    add_column :behavior_events, :visit_id, :string, index: true unless column_exists?(:behavior_events, :visit_id)
    add_column :behavior_events, :visitor_id, :string, index: true unless column_exists?(:behavior_events, :visitor_id)
    
    add_index :behavior_events, [:visit_id, :created_at] unless index_exists?(:behavior_events, [:visit_id, :created_at])
    add_index :behavior_events, [:visitor_id, :created_at] unless index_exists?(:behavior_events, [:visitor_id, :created_at])
  end
end

