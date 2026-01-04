# frozen_string_literal: true

require "spec_helper"

RSpec.describe BehaviorAnalytics::Context do
  describe "#initialize" do
    it "creates a context with tenant_id" do
      context = described_class.new(tenant_id: "tenant_123")
      expect(context.tenant_id).to eq("tenant_123")
    end

    it "accepts tenant as alias" do
      context = described_class.new(tenant: "tenant_123")
      expect(context.tenant_id).to eq("tenant_123")
    end

    it "accepts user as alias" do
      context = described_class.new(user: "user_456")
      expect(context.user_id).to eq("user_456")
    end
  end

  describe "#valid?" do
    it "returns true for valid context" do
      context = described_class.new(tenant_id: "tenant_123")
      expect(context.valid?).to be true
    end

    it "returns false for invalid context" do
      context = described_class.new(tenant_id: nil)
      expect(context.valid?).to be false
    end
  end

  describe "#validate!" do
    it "raises error for invalid context" do
      context = described_class.new(tenant_id: nil)
      expect { context.validate! }.to raise_error(BehaviorAnalytics::Error)
    end
  end
end

