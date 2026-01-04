# frozen_string_literal: true

require "spec_helper"
require "active_support/core_ext/numeric/time"
require "active_support/core_ext/time"

RSpec.describe BehaviorAnalytics::Storage::InMemoryAdapter do
  let(:adapter) { described_class.new }
  let(:context) do
    BehaviorAnalytics::Context.new(tenant_id: "tenant_123", user_id: "user_456")
  end

  describe "#save_events" do
    it "saves events" do
      event = BehaviorAnalytics::Event.new(
        tenant_id: "tenant_123",
        event_name: "test_event"
      )
      adapter.save_events([event])
      expect(adapter.event_count(context)).to eq(1)
    end
  end

  describe "#events_for_context" do
    it "filters events by tenant" do
      event1 = BehaviorAnalytics::Event.new(
        tenant_id: "tenant_123",
        event_name: "event1"
      )
      event2 = BehaviorAnalytics::Event.new(
        tenant_id: "tenant_456",
        event_name: "event2"
      )
      adapter.save_events([event1, event2])

      context1 = BehaviorAnalytics::Context.new(tenant_id: "tenant_123")
      expect(adapter.events_for_context(context1).count).to eq(1)
    end

    it "filters by date range" do
      old_event = BehaviorAnalytics::Event.new(
        tenant_id: "tenant_123",
        event_name: "old",
        created_at: Time.now - (10 * 24 * 60 * 60)
      )
      new_event = BehaviorAnalytics::Event.new(
        tenant_id: "tenant_123",
        event_name: "new",
        created_at: Time.now
      )
      adapter.save_events([old_event, new_event])

      events = adapter.events_for_context(
        context,
        since: Time.now - (5 * 24 * 60 * 60)
      )
      expect(events.count).to eq(1)
      expect(events.first[:event_name]).to eq("new")
    end
  end

  describe "#unique_users" do
    it "counts unique users" do
      adapter.save_events([
        BehaviorAnalytics::Event.new(
          tenant_id: "tenant_123",
          user_id: "user_1",
          event_name: "event1"
        ),
        BehaviorAnalytics::Event.new(
          tenant_id: "tenant_123",
          user_id: "user_2",
          event_name: "event2"
        ),
        BehaviorAnalytics::Event.new(
          tenant_id: "tenant_123",
          user_id: "user_1",
          event_name: "event3"
        )
      ])

      context_for_test = BehaviorAnalytics::Context.new(tenant_id: "tenant_123")
      expect(adapter.unique_users(context_for_test)).to eq(2)
    end
  end
end

