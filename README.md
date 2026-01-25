# Behavior Analytics

[![Gem Version](https://badge.fury.io/rb/behavior_analytics.svg)](https://badge.fury.io/rb/behavior_analytics)
[![Ruby Version](https://img.shields.io/badge/ruby-%3E%3D%203.0.0-brightgreen)](https://www.ruby-lang.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A comprehensive Ruby gem for tracking user behavior events with multi-tenant support, visit/session management, device detection, geographic analytics, and advanced querying capabilities with enterprise-grade features.

## Features

### Core Features
- **Flexible Context Tracking**: Track events with multi-tenant support, user types, and custom filters
- **Event Buffering**: Efficient batch processing with configurable buffer size and flush intervals
- **Visit/Session Management**: Automatic visit tracking with session management, visitor identification, and visit analytics
- **Device & Browser Detection**: Automatic device, browser, and OS detection from user agents
- **Geographic Analytics**: Country, city, and region tracking from IP addresses
- **Referrer Analytics**: UTM parameter tracking, source analysis, and search keyword extraction

### Analytics & Insights
- **Comprehensive Analytics**: 
  - Event counts and aggregations
  - Engagement scoring with customizable weights
  - Time-based analytics (hourly, daily, weekly, monthly)
  - Feature usage statistics
  - Funnel analysis
  - Cohort analysis
  - Retention tracking
- **Geographic Analytics**: Country/city breakdowns, device/browser statistics
- **Referrer Analytics**: Traffic source analysis, UTM campaign tracking, search keyword insights

### Storage & Performance
- **Multiple Storage Adapters**: 
  - ActiveRecord adapter for production use
  - In-memory adapter for testing
  - Redis adapter for high-throughput scenarios
  - Elasticsearch adapter for advanced search
  - Kafka adapter for event streaming
- **Async Processing**: Background job support (Sidekiq, DelayedJob, ActiveJob)
- **Event Streaming**: Real-time event pub/sub system

### Developer Experience
- **Simplified API**: Simple tracking API with automatic context resolution
- **Rails Integration**: Automatic API call tracking via middleware with selective tracking
- **Query Interface**: Fluent query builder for filtering events with advanced aggregations
- **JavaScript Client**: Frontend tracking with automatic page views and click tracking
- **Data Retention**: Automatic cleanup policies for visits and events

## Installation

### Requirements

- Ruby >= 3.0.0
- Rails >= 6.0 (for Rails integration)
- ActiveSupport >= 6.0

### Install via Bundler

Add this line to your application's Gemfile:

```ruby
gem 'behavior_analytics', '~> 2.2'
```

And then execute:

```bash
$ bundle install
```

### Install via RubyGems

Or install it directly:

```bash
$ gem install behavior_analytics
```

### Current Version

The latest stable version is **2.2.2**. See [CHANGELOG.md](CHANGELOG.md) for version history.

## Rails Setup

### 1. Run the generator

```bash
rails generate behavior_analytics:install
```

This will:
- Create migrations for the `behavior_events` and `behavior_visits` tables
- Create an initializer at `config/initializers/behavior_analytics.rb`
- Create models at `app/models/behavior_analytics_event.rb` and `app/models/behavior_analytics_visit.rb`

**Note**: If you're upgrading from v2.1.x or earlier, you'll need to run the new migrations for visit tracking features.

### 2. Run the migrations

```bash
rails db:migrate
```

This will create:
- `behavior_events` table for event tracking
- `behavior_visits` table for visit/session tracking
- Indexes for optimal query performance

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

  # Visit/Session Management (v2.2+)
  config.track_visits = true                    # Enable visit tracking (requires migrations)
  config.visit_duration = 30.minutes            # Visit expires after 30 min of inactivity
  config.track_device_info = true               # Auto-detect device, browser, OS
  config.track_geolocation = true               # Auto-detect country/city from IP
  config.device_detector = :simple              # :simple, :browser, or :user_agent_parser
  
  # Note: For better device detection, add 'browser' or 'user_agent_parser' gem
  # For geolocation, add 'geocoder' gem

  # Data Retention
  config.visit_retention_days = 90              # Keep visits for 90 days
  config.event_retention_days = 365            # Keep events for 1 year

  # Single-tenant support
  config.default_tenant_id = "global"          # For non-multi-tenant systems

  # Optional: Advanced features
  config.use_async = false                      # Enable async processing
  config.debug_mode = Rails.env.development?   # Enable debug logging
end
```

### 4. Include in ApplicationController

```ruby
class ApplicationController < ActionController::Base
  include BehaviorAnalytics::Integrations::Rails
end
```

### 5. (Optional) Add JavaScript Client

Include the JavaScript client in your layout:

```erb
<!-- app/views/layouts/application.html.erb -->
<%= javascript_include_tag 'behavior_analytics' %>
```

Or use the inline script generator:

```erb
<script>
  <%= BehaviorAnalytics::Javascript::Client.generate_script(
    tracker_url: behavior_analytics_track_path,
    auto_track: true
  ).html_safe %>
</script>
```

## Usage

### Simplified API (v2.2+)

The gem provides a simplified API for easy tracking without needing to create context objects manually:

```ruby
# Simple event tracking with automatic context resolution
BehaviorAnalytics.track("button_click", properties: { button: "signup" })

# Page view tracking
BehaviorAnalytics.track_page_view(path: "/dashboard")

# Click tracking
BehaviorAnalytics.track_click(element: "signup_button", properties: { location: "header" })

# Conversion tracking
BehaviorAnalytics.track_conversion(conversion_name: "signup", value: 99.99)

# Or use the helper methods in controllers
class ApplicationController < ActionController::Base
  include BehaviorAnalytics::Helpers::TrackingHelper

  def create
    # ... create logic ...
    track_event("project_created", properties: { project_id: @project.id })
  end
end
```

### Visit/Session Management

Visits are automatically created and tracked when visit tracking is enabled:

```ruby
# Visits are automatically created on first request
# You can access the current visit in your controllers:

class ApplicationController < ActionController::Base
  include BehaviorAnalytics::Integrations::Rails

  def current_visit
    @current_visit ||= visit_manager&.find_or_create_visit(
      visitor_token: visit_auto_creator.get_or_create_visitor_token(request),
      tenant_id: current_tenant&.id,
      user_id: current_user&.id,
      ip: request.ip,
      user_agent: request.user_agent,
      referrer: request.referer,
      landing_page: request.path
    )
  end
end

# Query visits
tracker = BehaviorAnalytics.create_tracker
visit_manager = BehaviorAnalytics::Visits::Manager.new(
  storage_adapter: tracker.storage_adapter
)

# Get user's visits
user_visits = visit_manager.find_visits_by_user(user_id, limit: 100)

# Get visitor's visits (anonymous)
visitor_visits = visit_manager.find_visits_by_visitor(visitor_token, limit: 100)

# Link anonymous visits to user on login
user_resolver = BehaviorAnalytics::Identification::UserResolver.new(
  visit_manager: visit_manager
)
user_resolver.identify_user(user_id, visitor_token: visitor_token)
```

### Device & Browser Detection

Device information is automatically detected and stored in visits:

```ruby
# Device detection happens automatically when track_device_info is enabled
# Visit will include:
# - browser: "Chrome", "Safari", "Firefox", etc.
# - os: "iOS", "Android", "Windows", "Mac OS", etc.
# - device_type: "mobile", "tablet", "desktop"

# You can also manually detect device info:
detector = BehaviorAnalytics::Detection::DeviceDetector.new(strategy: :simple)
device_info = detector.detect(request.user_agent)
# => { browser: "Chrome", os: "Mac OS", device_type: "desktop" }
```

### Geographic Analytics

Geographic information is automatically detected from IP addresses:

```ruby
# Geolocation happens automatically when track_geolocation is enabled
# Visit will include:
# - country: "United States"
# - city: "San Francisco"
# - country_code: "US"

# Query geographic analytics
analytics = tracker.analytics

# Country breakdown
countries = analytics.geographic.country_breakdown(context)
# => [{ country: "United States", count: 150 }, { country: "Canada", count: 50 }]

# City breakdown
cities = analytics.geographic.city_breakdown(context)
# => [{ city: "San Francisco", count: 75 }, { city: "New York", count: 50 }]

# Device breakdown
devices = analytics.geographic.device_breakdown(context)
# => [{ device: "desktop", count: 100 }, { device: "mobile", count: 50 }]

# Browser breakdown
browsers = analytics.geographic.browser_breakdown(context)
# => [{ browser: "Chrome", count: 120 }, { browser: "Safari", count: 30 }]
```

### Referrer Analytics

Track traffic sources, UTM parameters, and search keywords:

```ruby
analytics = tracker.analytics

# Traffic source breakdown
sources = analytics.referrer.source_breakdown(context)
# => [{ source: "google", count: 100 }, { source: "direct", count: 50 }]

# UTM source breakdown
utm_sources = analytics.referrer.utm_source_breakdown(context)
# => [{ utm_source: "newsletter", count: 75 }, { utm_source: "social", count: 25 }]

# UTM campaign breakdown
campaigns = analytics.referrer.utm_campaign_breakdown(context)
# => [{ utm_campaign: "summer_sale", count: 50 }, { utm_campaign: "winter_promo", count: 30 }]

# Search keyword breakdown
keywords = analytics.referrer.search_keyword_breakdown(context)
# => [{ keyword: "ruby gem", count: 20 }, { keyword: "analytics", count: 15 }]

# Referring domain breakdown
domains = analytics.referrer.referring_domain_breakdown(context)
# => [{ domain: "google.com", count: 100 }, { domain: "twitter.com", count: 25 }]
```

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

# Funnel analysis
funnel = analytics.funnels.create(
  name: "signup_funnel",
  steps: ["page_view", "signup_form", "signup_submit", "email_verified"]
)
conversion_rate = funnel.conversion_rate(context)

# Cohort analysis
cohort = analytics.cohorts.create(
  name: "signup_cohort",
  event_name: "signup",
  period: :monthly
)
cohort_data = cohort.analyze(context)

# Retention analysis
retention = analytics.retention.calculate(
  context: context,
  event_name: "login",
  period: :weekly
)
```

### Data Retention & Cleanup

Automatically clean up old visits and events:

```ruby
# Configure retention policy
retention_policy = BehaviorAnalytics::Cleanup::RetentionPolicy.new(
  visit_retention_days: 90,
  event_retention_days: 365
)

# Create scheduler
scheduler = BehaviorAnalytics::Cleanup::Scheduler.new(
  storage_adapter: tracker.storage_adapter,
  retention_policy: retention_policy
)

# Cleanup old data
results = scheduler.cleanup_all
# => { visits: 1500, events: 50000 }

# Or cleanup separately
deleted_visits = scheduler.cleanup_visits
deleted_events = scheduler.cleanup_events

# Schedule cleanup job (e.g., in a cron job or scheduled task)
# config/schedule.rb (whenever gem)
every 1.day, at: '2:00 am' do
  runner "BehaviorAnalytics::Cleanup::Scheduler.new(
    storage_adapter: BehaviorAnalytics.configuration.storage_adapter,
    retention_policy: BehaviorAnalytics::Cleanup::RetentionPolicy.new(
      visit_retention_days: BehaviorAnalytics.configuration.visit_retention_days,
      event_retention_days: BehaviorAnalytics.configuration.event_retention_days
    )
  ).cleanup_all"
end
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

# Advanced filtering
events = query
  .with_metadata(key: "feature", value: "advanced_search")
  .with_path("/api/search")
  .with_method("POST")
  .with_status_code(200)
  .group_by(:user_id)
  .aggregate(field: :duration_ms, function: :avg)
  .execute

# Visit-based queries
visit_events = query
  .for_visit(visit_token)
  .with_event_type(:custom)
  .execute
```

### JavaScript Client (v2.2+)

The JavaScript client provides automatic frontend tracking. The client file is included in the gem at `vendor/assets/javascripts/behavior_analytics.js`:

```javascript
// Automatic tracking (enabled by default)
// - Page views on load
// - Clicks on elements with data-track attribute
// - Form submissions with data-track attribute

// Manual tracking
BehaviorAnalytics.track("button_click", { button: "signup" });
BehaviorAnalytics.trackPageView();
BehaviorAnalytics.trackClick(element, { location: "header" });

// HTML attributes for automatic tracking
<button data-track="signup_click" data-track-properties='{"plan": "premium"}'>
  Sign Up
</button>

<form data-track="newsletter_signup">
  <!-- form fields -->
</form>
```

### User Identification & Visitor Tracking

Track anonymous visitors and merge with user accounts:

```ruby
# Identify user on login (merges anonymous visits)
user_resolver = BehaviorAnalytics::Identification::UserResolver.new(
  visit_manager: visit_manager
)

# On user login
user_resolver.identify_user(
  user_id: current_user.id,
  visitor_token: cookies[:behavior_visitor_token]
)

# Get all visits for a user (including anonymous visits before login)
user_visits = user_resolver.get_user_visits(user_id)

# Get visits for anonymous visitor
visitor_visits = user_resolver.get_visitor_visits(visitor_token)
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

### Core Configuration

- `storage_adapter`: Storage adapter instance (required)
- `batch_size`: Number of events to buffer before flushing (default: 100)
- `flush_interval`: Seconds between automatic flushes (default: 300)
- `context_resolver`: Lambda/proc to resolve context from requests
- `scoring_weights`: Hash of weights for engagement scoring
- `default_tenant_id`: Default tenant ID for single-tenant systems (default: "default")

### Visit/Session Management

- `track_visits`: Enable visit tracking (default: false)
- `visit_duration`: Visit expiration time after inactivity (default: 30.minutes)
- `track_device_info`: Enable automatic device/browser detection (default: false)
- `track_geolocation`: Enable automatic geographic detection from IP (default: false)
- `device_detector`: Device detection strategy - `:simple`, `:browser`, or `:user_agent_parser` (default: `:simple`)

### Data Retention

- `visit_retention_days`: Days to keep visits before cleanup (default: 90)
- `event_retention_days`: Days to keep events before cleanup (default: 365)

### Advanced Features

- `use_async`: Enable async event processing (default: false)
- `async_processor`: Async processor instance (Sidekiq, DelayedJob, ActiveJob)
- `event_stream`: Event streaming instance for pub/sub
- `hooks_manager`: Event hooks manager for lifecycle callbacks
- `sampling_strategy`: Event sampling strategy
- `rate_limiter`: Rate limiting configuration
- `schema_validator`: Event schema validator
- `metrics`: Metrics collection instance
- `tracer`: Distributed tracing instance
- `debug_mode`: Enable debug logging (default: development mode)
- `logger`: Custom logger instance

### Rails Integration

- `tracking_whitelist`: Array of path patterns to whitelist (nil = track all)
- `tracking_blacklist`: Array of path patterns to blacklist (default: [])
- `skip_bots`: Skip tracking for bot user agents (default: true)
- `controller_action_filters`: Hash of controllers/actions to filter
- `slow_query_threshold`: Log slow queries above threshold (ms)
- `track_middleware_requests`: Track requests via middleware (default: false)

## Event Types

- `:api_call` - HTTP API requests (automatically tracked via Rails integration)
- `:feature_usage` - Feature usage events
- `:custom` - Custom business events

## Visit Model

Visits track user sessions and include:

- `visit_token`: Unique identifier for the visit
- `visitor_token`: Anonymous visitor identifier (persists across visits)
- `tenant_id`: Multi-tenant identifier
- `user_id`: User identifier (set when user logs in)
- `ip`: IP address
- `user_agent`: Browser user agent string
- `referrer`: HTTP referrer
- `landing_page`: First page visited in session
- `browser`: Detected browser (Chrome, Safari, Firefox, etc.)
- `os`: Detected operating system (iOS, Android, Windows, etc.)
- `device_type`: Device type (mobile, tablet, desktop)
- `country`: Country from IP geolocation
- `city`: City from IP geolocation
- `utm_source`, `utm_medium`, `utm_campaign`, `utm_term`, `utm_content`: UTM parameters
- `referring_domain`: Extracted referring domain
- `search_keyword`: Extracted search keyword from search engines
- `started_at`: Visit start time
- `ended_at`: Visit end time (null for active visits)

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

## Advanced Usage

### Async Processing

Process events asynchronously using background jobs:

```ruby
# Configure async processor
BehaviorAnalytics.configure do |config|
  config.use_async = true
  config.async_processor = BehaviorAnalytics::Processors::BackgroundJobProcessor.new(
    job_class: BehaviorAnalytics::Jobs::ActiveEventJob
  )
end

# Events will be processed in background
tracker.track(context: context, event_name: "event")
```

### Event Hooks

Execute callbacks on event lifecycle:

```ruby
BehaviorAnalytics.configuration.hooks_manager.register_before_track do |event, context|
  # Modify event before tracking
  event[:metadata][:custom_field] = "value"
end

BehaviorAnalytics.configuration.hooks_manager.register_after_track do |event, context|
  # Execute after tracking
  NotificationService.notify(event)
end
```

### Event Sampling

Sample events to reduce storage:

```ruby
sampling_strategy = BehaviorAnalytics::Sampling::Strategy.new(
  sample_rate: 0.1  # Sample 10% of events
)
BehaviorAnalytics.configuration.sampling_strategy = sampling_strategy
```

### Rate Limiting

Limit events per context:

```ruby
rate_limiter = BehaviorAnalytics::Throttling::Limiter.new(
  max_events_per_minute: 100
)
BehaviorAnalytics.configuration.rate_limiter = rate_limiter
```

### Event Schema Validation

Validate events against JSON schemas:

```ruby
schema = BehaviorAnalytics::Schema::Definition.new(
  event_name: "signup",
  schema: {
    type: "object",
    properties: {
      email: { type: "string" },
      plan: { type: "string", enum: ["basic", "premium"] }
    },
    required: ["email"]
  }
)

validator = BehaviorAnalytics::Schema::Validator.new
validator.register_schema(schema)
BehaviorAnalytics.configuration.schema_validator = validator
```

## Migration Guide

### From v1 to v2

v2 is backward compatible with v1. Existing code will continue to work:

```ruby
# v1 code still works
tracker.track(context: context, event_name: "event")

# New v2 features are opt-in
BehaviorAnalytics.configure do |config|
  config.track_visits = true  # Enable new features
end
```

### Enabling Visit Tracking

1. Run migrations:
```bash
rails db:migrate
```

2. Enable in configuration:
```ruby
BehaviorAnalytics.configure do |config|
  config.track_visits = true
  config.track_device_info = true
  config.track_geolocation = true
end
```

3. Visits will be automatically created on requests

### Migrating Existing Events

If you have existing events and want to link them to visits:

```ruby
# Create visits for existing events (one-time migration)
BehaviorAnalyticsEvent.find_each do |event|
  visit = visit_manager.find_or_create_visit(
    visitor_token: generate_visitor_token_for_event(event),
    tenant_id: event.tenant_id,
    user_id: event.user_id,
    ip: event.ip,
    user_agent: event.user_agent
  )
  event.update(visit_id: visit.visit_token, visitor_id: visit.visitor_token)
end
```

## Performance Considerations

### Database Indexes

The migrations create indexes for optimal query performance. For high-volume applications, consider:

- Additional composite indexes based on your query patterns
- Partitioning large tables by date
- Archiving old data to separate tables

### Batch Processing

Configure appropriate batch sizes based on your volume:

```ruby
# High volume
config.batch_size = 500
config.flush_interval = 60  # 1 minute

# Low volume
config.batch_size = 50
config.flush_interval = 600  # 10 minutes
```

### Async Processing

For high-throughput scenarios, use async processing:

```ruby
config.use_async = true
config.async_processor = BehaviorAnalytics::Processors::BackgroundJobProcessor.new(
  job_class: BehaviorAnalytics::Jobs::SidekiqEventJob
)
```

## Troubleshooting

### Visits Not Being Created

1. Check that `track_visits` is enabled:
```ruby
BehaviorAnalytics.configuration.track_visits # => true
```

2. Verify migrations are run:
```bash
rails db:migrate:status
```

3. Check Rails integration is included:
```ruby
class ApplicationController < ActionController::Base
  include BehaviorAnalytics::Integrations::Rails
end
```

### Device Detection Not Working

1. Ensure `track_device_info` is enabled
2. Check user agent is being passed:
```ruby
request.user_agent  # Should not be nil
```

3. For better detection, use a gem:
```ruby
# Gemfile
gem 'browser'  # or 'user_agent_parser'

# config
config.device_detector = :browser
```

### Geolocation Not Working

1. Ensure `track_geolocation` is enabled
2. Install geocoding gem:
```ruby
# Gemfile
gem 'geocoder'

# Will automatically use Geocoder for IP lookup
```

3. For production, consider MaxMind GeoIP2 database

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests.

To install this gem onto your local machine, run `bundle exec rake install`.

### Running Tests

```bash
bundle exec rspec
```

### Building the Gem

```bash
gem build behavior_analytics.gemspec
```

### Publishing

```bash
gem push behavior_analytics-x.x.x.gem
```

## Complete Example

Here's a complete example showing all features:

```ruby
# config/initializers/behavior_analytics.rb
BehaviorAnalytics.configure do |config|
  config.storage_adapter = BehaviorAnalytics::Storage::ActiveRecordAdapter.new(
    model_class: BehaviorAnalyticsEvent
  )
  
  # Visit tracking
  config.track_visits = true
  config.visit_duration = 30.minutes
  config.track_device_info = true
  config.track_geolocation = true
  
  # Data retention
  config.visit_retention_days = 90
  config.event_retention_days = 365
  
  # Single-tenant
  config.default_tenant_id = "my_app"
end

# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include BehaviorAnalytics::Integrations::Rails
  include BehaviorAnalytics::Helpers::TrackingHelper
  
  private
  
  def identify_user_after_login
    if user_signed_in?
      user_resolver = BehaviorAnalytics::Identification::UserResolver.new(
        visit_manager: visit_manager
      )
      user_resolver.identify_user(
        current_user.id,
        visitor_token: cookies[:behavior_visitor_token]
      )
    end
  end
end

# app/controllers/projects_controller.rb
class ProjectsController < ApplicationController
  def create
    @project = Project.create(project_params)
    
    # Track with simplified API
    track_event("project_created", properties: {
      project_id: @project.id,
      project_name: @project.name
    })
    
    redirect_to @project
  end
  
  def show
    @project = Project.find(params[:id])
    
    # Track page view
    track_page_view(path: request.path)
  end
end

# app/jobs/cleanup_job.rb
class CleanupJob < ApplicationJob
  def perform
    retention_policy = BehaviorAnalytics::Cleanup::RetentionPolicy.new(
      visit_retention_days: BehaviorAnalytics.configuration.visit_retention_days,
      event_retention_days: BehaviorAnalytics.configuration.event_retention_days
    )
    
    scheduler = BehaviorAnalytics::Cleanup::Scheduler.new(
      storage_adapter: BehaviorAnalytics.configuration.storage_adapter,
      retention_policy: retention_policy
    )
    
    scheduler.cleanup_all
  end
end

# Analytics dashboard
class AnalyticsController < ApplicationController
  def index
    tracker = BehaviorAnalytics.create_tracker
    context = BehaviorAnalytics::Context.new(
      tenant_id: current_tenant.id
    )
    
    @analytics = {
      event_count: tracker.analytics.event_count(context, since: 7.days.ago),
      unique_users: tracker.analytics.unique_users(context),
      engagement_score: tracker.analytics.engagement_score(context),
      daily_activity: tracker.analytics.daily_activity(context),
      top_features: tracker.analytics.top_features(context, limit: 10),
      countries: tracker.analytics.geographic.country_breakdown(context),
      sources: tracker.analytics.referrer.source_breakdown(context)
    }
  end
end
```

## API Reference

### BehaviorAnalytics Module

#### Class Methods

- `BehaviorAnalytics.configure { |config| ... }` - Configure the gem
- `BehaviorAnalytics.create_tracker(options = {})` - Create a tracker instance
- `BehaviorAnalytics.track(event_name, properties: {}, **options)` - Simplified tracking
- `BehaviorAnalytics.track_page_view(path:, properties: {}, **options)` - Track page view
- `BehaviorAnalytics.track_click(element:, properties: {}, **options)` - Track click
- `BehaviorAnalytics.track_conversion(conversion_name:, value: nil, properties: {}, **options)` - Track conversion
- `BehaviorAnalytics.tracker` - Get default tracker instance

### Tracker Class

#### Methods

- `track(context:, event_name:, event_type: :custom, metadata: {}, **options)` - Track event
- `track_api_call(context:, method:, path:, status_code:, duration_ms: nil, **options)` - Track API call
- `track_feature_usage(context:, feature:, metadata: {}, **options)` - Track feature usage
- `flush` - Flush buffered events
- `analytics` - Get analytics engine
- `query` - Get query builder
- `subscribe_to_stream(filter: nil, &block)` - Subscribe to event stream

### Analytics Engine

#### Methods

- `event_count(context, options = {})` - Count events
- `unique_users(context, options = {})` - Count unique users
- `active_days(context, options = {})` - Count active days
- `engagement_score(context, options = {})` - Calculate engagement score
- `activity_timeline(context, period: :daily, options = {})` - Get activity timeline
- `daily_activity(context, options = {})` - Get daily activity
- `feature_usage_stats(context, options = {})` - Get feature usage statistics
- `top_features(context, limit: 10, options = {})` - Get top features
- `funnels` - Access funnel analysis
- `cohorts` - Access cohort analysis
- `retention` - Access retention analysis
- `geographic` - Access geographic analytics
- `referrer` - Access referrer analytics

### Visit Manager

#### Methods

- `find_or_create_visit(visitor_token:, tenant_id: nil, user_id: nil, **options)` - Find or create visit
- `find_active_visit(visitor_token, user_id = nil)` - Find active visit
- `save_visit(visit)` - Save visit
- `end_visit(visit_token)` - End visit
- `link_user_to_visits(visitor_token, user_id)` - Link visits to user
- `find_visits_by_user(user_id, limit: 100)` - Get user's visits
- `find_visits_by_visitor(visitor_token, limit: 100)` - Get visitor's visits

### User Resolver

#### Methods

- `identify_user(user_id, visitor_token: nil, request: nil)` - Identify user and merge visits
- `merge_visits(visitor_token, user_id)` - Merge anonymous visits with user
- `get_user_visits(user_id, limit: 100)` - Get user's visits
- `get_visitor_visits(visitor_token, limit: 100)` - Get visitor's visits

## Best Practices

### 1. Visit Tracking

- Enable visit tracking for web applications to get session analytics
- Disable for API-only applications to reduce overhead
- Use `visit_duration` to match your session timeout

### 2. Device Detection

- Use `:simple` for basic detection (no dependencies)
- Use `:browser` or `:user_agent_parser` for more accurate detection (requires gems)
- Consider caching device info to reduce processing

### 3. Geolocation

- Use geocoding service for production (Geocoder gem recommended)
- Consider privacy implications of IP tracking
- Cache geolocation results to reduce API calls

### 4. Data Retention

- Set appropriate retention periods based on your needs
- Schedule cleanup jobs to run regularly
- Archive old data before deletion if needed for compliance

### 5. Performance

- Use async processing for high-volume applications
- Configure appropriate batch sizes
- Monitor query performance and add indexes as needed
- Consider using Redis or Elasticsearch adapters for scale

### 6. Privacy & Compliance

- Be transparent about data collection
- Implement data deletion on user request
- Consider anonymizing IP addresses
- Comply with GDPR, CCPA, and other regulations

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/nerdawey/behavior_analytics.

### Development Setup

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Run the test suite: `bundle exec rspec`
6. Submit a pull request

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
