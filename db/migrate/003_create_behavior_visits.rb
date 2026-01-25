# frozen_string_literal: true

class CreateBehaviorVisits < ActiveRecord::Migration[7.0]
  def change
    create_table :behavior_visits do |t|
      t.string :visit_token, null: false, index: true
      t.string :visitor_token, null: false, index: true
      t.string :tenant_id, index: true
      t.string :user_id, index: true
      t.string :ip
      t.text :user_agent
      t.string :referrer
      t.string :landing_page
      t.string :browser
      t.string :os
      t.string :device_type
      t.string :country
      t.string :city
      t.string :utm_source
      t.string :utm_medium
      t.string :utm_campaign
      t.string :utm_term
      t.string :utm_content
      t.string :referring_domain
      t.string :search_keyword
      t.datetime :started_at, null: false
      t.datetime :ended_at
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
    end

    add_index :behavior_visits, [:tenant_id, :started_at]
    add_index :behavior_visits, [:visitor_token, :started_at]
    add_index :behavior_visits, [:user_id, :started_at]
    add_index :behavior_visits, [:visit_token, :visitor_token]
  end
end

