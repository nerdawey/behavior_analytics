# frozen_string_literal: true

require_relative "behavior_analytics/version"
require_relative "behavior_analytics/event"
require_relative "behavior_analytics/context"
require_relative "behavior_analytics/tracker"
require_relative "behavior_analytics/query"
require_relative "behavior_analytics/storage/adapter"
require_relative "behavior_analytics/storage/in_memory_adapter"
require_relative "behavior_analytics/storage/active_record_adapter"
require_relative "behavior_analytics/analytics/engine"

begin
  require_relative "behavior_analytics/integrations/rails"
rescue LoadError
end

module BehaviorAnalytics
  class Error < StandardError; end

  class Configuration
    attr_accessor :storage_adapter, :batch_size, :flush_interval, :context_resolver, :scoring_weights

    def initialize
      @batch_size = 100
      @flush_interval = 300
      @scoring_weights = {
        activity: 0.4,
        unique_users: 0.3,
        feature_diversity: 0.2,
        time_in_trial: 0.1
      }
    end
  end

  class << self
    attr_writer :configuration

    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
    end

    def create_tracker(options = {})
      Tracker.new(options)
    end
  end
end
