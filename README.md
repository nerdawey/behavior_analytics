# Behavior Analytics

A Ruby gem for tracking user behavior events with multi-tenant support, computing analytics (engagement scores, time-based trends, feature usage), and supporting API calls, feature usage, and custom events.

## Features

- **Flexible Context Tracking**: Track events with multi-tenant support, user types, and custom filters
- **Event Buffering**: Efficient batch processing with configurable buffer size and flush intervals
- **Comprehensive Analytics**: 
  - Event counts and aggregations
  - Engagement scoring with customizable weights
  - Time-based analytics (hourly, daily, weekly, monthly)
  - Feature usage statistics
- **Storage Adapters**: 
  - ActiveRecord adapter for production use
  - In-memory adapter for testing
- **Rails Integration**: Automatic API call tracking via middleware
- **Query Interface**: Fluent query builder for filtering events

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'behavior_analytics'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install behavior_analytics
```

## Rails Setup

### 1. Run the generator

```bash
rails generate behavior_analytics:install
```

This will:
- Create a migration for the `behavior_events` table
- Create an initializer at `config/initializers/behavior_analytics.rb`
- Create a model at `app/models/behavior_analytics_event.rb`

### 2. Run the migration

```bash
rails db:migrate
```

### 3. Configure the initializer

Edit `config/initializers/behavior_analytics.rb`:

```ruby
BehaviorAnalytics.configure do |config|
  # Configure storage adapter (required)
  config.storage_adapter = BehaviorAnalytics::Storage::ActiveRecordAdapter.new(
    model_class: BehaviorAnalyticsEvent
  )

  # Configure batching
  config.batch_size = 100
  config.flush_interval = 300 # 5 minutes

  # Configure context resolver (optional)
  config.context_resolver = ->(request) {
    {
      tenant_id: current_tenant&.id,
      user_id: current_user&.id,
      user_type: current_user&.account_type
    }
  }

  # Configure engagement scoring weights
  config.scoring_weights = {
    activity: 0.4,
    unique_users: 0.3,
    feature_diversity: 0.2,
    time_in_trial: 0.1
  }
end
```

### 4. Include in ApplicationController

```ruby
class ApplicationController < ActionController::Base
  include BehaviorAnalytics::Integrations::Rails
end
```

## Usage

### Supported Business Cases

The gem is flexible and supports different business scenarios:

#### 1. Multi-Tenant Systems
Track events with tenant isolation for SaaS applications:

```ruby
context = BehaviorAnalytics::Context.new(
  tenant_id: "org_123",
  user_id: "user_456",
  user_type: "premium"
)
```

#### 2. Single-Tenant Web Apps
Track events for regular web applications without tenant concept:

```ruby
# Option A: Set default tenant (recommended)
BehaviorAnalytics.configure do |config|
  config.default_tenant_id = "global"
end

context = BehaviorAnalytics::Context.new(
  user_id: current_user.id,
  user_type: "admin"
)

# Option B: Track without tenant_id (uses session_id or user_id as identifier)
context = BehaviorAnalytics::Context.new(
  user_id: current_user.id
)
```

#### 3. API-Only Tracking
Track API calls without user context (for monitoring, analytics, etc.):

```ruby
# Track API calls directly without user context
tracker.track_api_call(
  context: BehaviorAnalytics::Context.new, # Empty context - uses session_id from request
  method: "POST",
  path: "/api/endpoint",
  status_code: 200,
  duration_ms: 150
)

# Or with minimal context
context = BehaviorAnalytics::Context.new(
  filters: { environment: "production", service: "api" }
)
```

#### 4. Anonymous/Public Tracking
Track events for anonymous users or public pages:

```ruby
context = BehaviorAnalytics::Context.new(
  filters: { page: "homepage", referrer: request.referer }
)

tracker.track(
  context: context,
  event_name: "page_view",
  metadata: { path: request.path }
)
```

### Basic Tracking

```ruby
# Create a tracker
tracker = BehaviorAnalytics.create_tracker

# Multi-tenant example
context = BehaviorAnalytics::Context.new(
  tenant_id: "org_123",
  user_id: "user_456",
  user_type: "trial"
)

# Single-tenant example (with default tenant)
context = BehaviorAnalytics::Context.new(
  user_id: "user_456",
  user_type: "trial"
)

# API-only example (no user context)
context = BehaviorAnalytics::Context.new

# Track a custom event
tracker.track(
  context: context,
  event_name: "project_created",
  metadata: { project_id: 789 }
)

# Track an API call
tracker.track_api_call(
  context: context,
  method: "POST",
  path: "/api/projects",
  status_code: 201,
  duration_ms: 150
)

# Track feature usage
tracker.track_feature_usage(
  context: context,
  feature: "advanced_search",
  metadata: { query: "..." }
)

# Flush buffered events
tracker.flush
```

### Analytics

```ruby
analytics = tracker.analytics

# Basic counts
event_count = analytics.event_count(context, since: 7.days.ago)
unique_users = analytics.unique_users(context)
active_days = analytics.active_days(context)

# Engagement scoring
score = analytics.engagement_score(context)
# => 75.5

# Time-based analytics
timeline = analytics.activity_timeline(context, period: :daily)
# => { 2024-01-01 => 10, 2024-01-02 => 15, ... }

daily = analytics.daily_activity(context, date_range: 7.days.ago..Time.current)

# Feature usage
feature_stats = analytics.feature_usage_stats(context)
# => { "projects" => 25, "search" => 10, ... }

top_features = analytics.top_features(context, limit: 10)
```

### Query Interface

```ruby
query = tracker.query

# Build complex queries
events = query
  .for_tenant("org_123")
  .for_user_type("trial")
  .with_event_type(:feature_usage)
  .since(7.days.ago)
  .limit(100)
  .execute

# Count events
count = query
  .for_tenant("org_123")
  .with_event_name("project_created")
  .count
```

### Custom Storage Adapter

```ruby
class MyCustomAdapter < BehaviorAnalytics::Storage::Adapter
  def save_events(events)
    # Your implementation
  end

  def events_for_context(context, options = {})
    # Your implementation
  end

  # ... implement other required methods
end

tracker = BehaviorAnalytics.create_tracker(
  storage_adapter: MyCustomAdapter.new
)
```

## Configuration Options

- `storage_adapter`: Storage adapter instance (required)
- `batch_size`: Number of events to buffer before flushing (default: 100)
- `flush_interval`: Seconds between automatic flushes (default: 300)
- `context_resolver`: Lambda/proc to resolve context from requests
- `scoring_weights`: Hash of weights for engagement scoring
- `default_tenant_id`: Default tenant ID for single-tenant systems (default: "default")

## Event Types

- `:api_call` - HTTP API requests
- `:feature_usage` - Feature usage events
- `:custom` - Custom business events

## Context

The `Context` class encapsulates tracking context and is flexible to support different business cases:

- `tenant_id` (optional) - Multi-tenant identifier. Only required for multi-tenant systems
- `user_id` (optional) - User identifier. Useful for user-based analytics
- `user_type` (optional) - User type (e.g., "trial", "premium", "admin")
- `filters` (optional) - Hash of custom filter criteria for additional context

### Context Validation

A context is valid if it has **at least one identifier**:
- `tenant_id` (for multi-tenant systems)
- `user_id` (for user-based tracking)
- `filters` with identifying information (for anonymous/public tracking)
- `session_id` (automatically added for API calls)

This allows the gem to support:
- ✅ Multi-tenant SaaS applications
- ✅ Single-tenant web applications
- ✅ API monitoring without user context
- ✅ Anonymous/public page tracking

### Examples by Use Case

**Multi-Tenant SaaS:**
```ruby
context = BehaviorAnalytics::Context.new(
  tenant_id: "org_123",  # Required
  user_id: "user_456",
  user_type: "premium"
)
```

**Single-Tenant Web App:**
```ruby
# Set default tenant (optional but recommended)
BehaviorAnalytics.configure do |config|
  config.default_tenant_id = "global"
end

# Track with just user_id
context = BehaviorAnalytics::Context.new(
  user_id: current_user.id,
  user_type: current_user.role
)
```

**API-Only Tracking:**
```ruby
# Track API calls without user context
context = BehaviorAnalytics::Context.new  # Empty context - session_id will be used
tracker.track_api_call(
  context: context,
  method: "POST",
  path: "/api/endpoint",
  status_code: 200
)
```

**Anonymous/Public Tracking:**
```ruby
context = BehaviorAnalytics::Context.new(
  filters: { 
    page_type: "public",
    referrer: request.referer 
  }
)
tracker.track(context: context, event_name: "page_view")
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests.

To install this gem onto your local machine, run `bundle exec rake install`.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/nerdawey/behavior_analytics.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
