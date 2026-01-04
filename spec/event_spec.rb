# frozen_string_literal: true

require "spec_helper"

RSpec.describe BehaviorAnalytics::Event do
  describe "#initialize" do
    it "creates an event with required fields" do
      event = described_class.new(
        tenant_id: "tenant_123",
        event_name: "test_event"
      )
      expect(event.tenant_id).to eq("tenant_123")
      expect(event.event_name).to eq("test_event")
      expect(event.id).not_to be_nil
    end

    it "raises error without tenant_id" do
      expect {
        described_class.new(event_name: "test_event")
      }.to raise_error(BehaviorAnalytics::Error, /tenant_id is required/)
    end

    it "raises error without event_name" do
      expect {
        described_class.new(tenant_id: "tenant_123")
      }.to raise_error(BehaviorAnalytics::Error, /event_name is required/)
    end

    it "raises error with invalid event_type" do
      expect {
        described_class.new(
          tenant_id: "tenant_123",
          event_name: "test",
          event_type: :invalid
        )
      }.to raise_error(BehaviorAnalytics::Error, /event_type must be one of/)
    end
  end

  describe "#to_h" do
    it "converts event to hash" do
      event = described_class.new(
        tenant_id: "tenant_123",
        event_name: "test_event",
        metadata: { key: "value" }
      )
      hash = event.to_h
      expect(hash[:tenant_id]).to eq("tenant_123")
      expect(hash[:event_name]).to eq("test_event")
      expect(hash[:metadata][:key]).to eq("value")
    end
  end
end

