# frozen_string_literal: true

require "spec_helper"

RSpec.describe BehaviorAnalytics do
  it "has a version number" do
    expect(BehaviorAnalytics::VERSION).not_to be nil
  end

  describe ".create_tracker" do
    it "creates a tracker instance" do
      tracker = BehaviorAnalytics.create_tracker(
        storage_adapter: BehaviorAnalytics::Storage::InMemoryAdapter.new
      )
      expect(tracker).to be_a(BehaviorAnalytics::Tracker)
    end
  end

  describe ".configure" do
    it "allows configuration" do
      BehaviorAnalytics.configure do |config|
        config.batch_size = 50
      end
      expect(BehaviorAnalytics.configuration.batch_size).to eq(50)
    end
  end
end

