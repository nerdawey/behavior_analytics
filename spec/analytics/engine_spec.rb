# frozen_string_literal: true

require "spec_helper"
require "active_support/core_ext/numeric/time"
require "active_support/core_ext/time"

RSpec.describe BehaviorAnalytics::Analytics::Engine do
  let(:storage_adapter) { BehaviorAnalytics::Storage::InMemoryAdapter.new }
  let(:engine) { described_class.new(storage_adapter) }
  let(:context) do
    BehaviorAnalytics::Context.new(tenant_id: "tenant_123", user_id: "user_456")
  end

  before do
    events = [
      BehaviorAnalytics::Event.new(
        tenant_id: "tenant_123",
        user_id: "user_456",
        event_name: "project_created",
        event_type: :feature_usage,
        metadata: { feature: "projects" },
        created_at: Time.now
      ),
      BehaviorAnalytics::Event.new(
        tenant_id: "tenant_123",
        user_id: "user_456",
        event_name: "api_call",
        event_type: :api_call,
        created_at: Time.now
      )
    ]
    storage_adapter.save_events(events)
  end

  describe "#event_count" do
    it "counts events for context" do
      expect(engine.event_count(context)).to eq(2)
    end
  end

  describe "#unique_users" do
    it "counts unique users" do
      expect(engine.unique_users(context)).to eq(1)
    end
  end

  describe "#active_days" do
    it "counts active days" do
      expect(engine.active_days(context)).to eq(1)
    end
  end

  describe "#engagement_score" do
    it "calculates engagement score" do
      score = engine.engagement_score(context)
      expect(score).to be_a(Numeric)
      expect(score).to be >= 0
      expect(score).to be <= 100
    end
  end

  describe "#feature_usage_stats" do
    it "returns feature usage statistics" do
      stats = engine.feature_usage_stats(context)
      expect(stats).to be_a(Hash)
      expect(stats["projects"]).to eq(1)
    end
  end

  describe "#top_features" do
    it "returns top features" do
      features = engine.top_features(context, limit: 10)
      expect(features).to be_a(Hash)
    end
  end
end

