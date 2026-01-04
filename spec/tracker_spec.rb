# frozen_string_literal: true

require "spec_helper"

RSpec.describe BehaviorAnalytics::Tracker do
  let(:storage_adapter) { BehaviorAnalytics::Storage::InMemoryAdapter.new }
  let(:tracker) { described_class.new(storage_adapter: storage_adapter) }
  let(:context) do
    BehaviorAnalytics::Context.new(
      tenant_id: "tenant_123",
      user_id: "user_456",
      user_type: "trial"
    )
  end

  describe "#track" do
    it "tracks an event" do
      tracker.track(
        context: context,
        event_name: "project_created",
        metadata: { project_id: 789 }
      )
      tracker.flush

      events = storage_adapter.events_for_context(context)
      expect(events.count).to eq(1)
      expect(events.first[:event_name]).to eq("project_created")
    end

    it "buffers events before flushing" do
      tracker.track(context: context, event_name: "event1")
      tracker.track(context: context, event_name: "event2")

      expect(storage_adapter.events_for_context(context).count).to eq(0)

      tracker.flush
      expect(storage_adapter.events_for_context(context).count).to eq(2)
    end
  end

  describe "#track_api_call" do
    it "tracks API calls with proper metadata" do
      tracker.track_api_call(
        context: context,
        method: "POST",
        path: "/api/projects",
        status_code: 201,
        duration_ms: 150
      )
      tracker.flush

      events = storage_adapter.events_for_context(context)
      expect(events.count).to eq(1)
      expect(events.first[:event_type]).to eq(:api_call)
      expect(events.first[:metadata][:method]).to eq("POST")
      expect(events.first[:metadata][:path]).to eq("/api/projects")
    end
  end

  describe "#track_feature_usage" do
    it "tracks feature usage" do
      tracker.track_feature_usage(
        context: context,
        feature: "advanced_search",
        metadata: { query: "test" }
      )
      tracker.flush

      events = storage_adapter.events_for_context(context)
      expect(events.count).to eq(1)
      expect(events.first[:event_type]).to eq(:feature_usage)
      expect(events.first[:metadata][:feature]).to eq("advanced_search")
    end
  end

  describe "#analytics" do
    it "returns an analytics engine" do
      expect(tracker.analytics).to be_a(BehaviorAnalytics::Analytics::Engine)
    end
  end

  describe "#query" do
    it "returns a query builder" do
      expect(tracker.query).to be_a(BehaviorAnalytics::Query)
    end
  end
end

