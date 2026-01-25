# frozen_string_literal: true

begin
  require "elasticsearch"
rescue LoadError
  raise LoadError, "Elasticsearch gem is required for ElasticsearchAdapter. Please add 'elasticsearch' to your Gemfile."
end

module BehaviorAnalytics
  module Storage
    class ElasticsearchAdapter < Adapter
      def initialize(client: nil, index_name: "behavior_events")
        @client = client || Elasticsearch::Client.new
        @index_name = index_name
        ensure_index_exists
      end

      def save_events(events)
        return if events.empty?

        body = events.map do |event|
          event_hash = event.is_a?(Hash) ? event : event.to_h
          {
            index: {
              _index: @index_name,
              _id: event_hash[:id] || SecureRandom.uuid,
              _type: "_doc",
              data: event_hash
            }
          }
        end

        @client.bulk(body: body)
      rescue StandardError => e
        raise Error, "Failed to save events to Elasticsearch: #{e.message}"
      end

      def events_for_context(context, options = {})
        context.validate!

        query = build_query(context, options)
        
        response = @client.search(
          index: @index_name,
          body: {
            query: query,
            sort: build_sort(options[:order_by]),
            size: options[:limit] || 100
          }
        )

        response["hits"]["hits"].map { |hit| hit["_source"].symbolize_keys }
      end

      def delete_old_events(before_date)
        @client.delete_by_query(
          index: @index_name,
          body: {
            query: {
              range: {
                created_at: {
                  lt: before_date.iso8601
                }
              }
            }
          }
        )
      end

      def event_count(context, options = {})
        context.validate!
        query = build_query(context, options)
        
        response = @client.count(
          index: @index_name,
          body: { query: query }
        )
        
        response["count"]
      end

      def unique_users(context, options = {})
        context.validate!
        query = build_query(context, options)
        
        response = @client.search(
          index: @index_name,
          body: {
            query: query,
            aggs: {
              unique_users: {
                cardinality: {
                  field: "user_id"
                }
              }
            },
            size: 0
          }
        )
        
        response["aggregations"]["unique_users"]["value"]
      end

      private

      def ensure_index_exists
        return if @client.indices.exists?(index: @index_name)
        
        @client.indices.create(
          index: @index_name,
          body: {
            mappings: {
              properties: {
                tenant_id: { type: "keyword" },
                user_id: { type: "keyword" },
                user_type: { type: "keyword" },
                event_name: { type: "keyword" },
                event_type: { type: "keyword" },
                metadata: { type: "object" },
                created_at: { type: "date" }
              }
            }
          }
        )
      end

      def build_query(context, options)
        must_clauses = []
        
        # Support different business cases:
        # - Multi-tenant: filter by tenant_id
        # - Single-tenant: filter by user_id (tenant_id may be nil)
        # - API-only: no strict filters required
        
        if context.has_tenant?
          must_clauses << { term: { tenant_id: context.tenant_id } }
        end
        
        if context.has_user?
          must_clauses << { term: { user_id: context.user_id } }
        end
        
        must_clauses << { term: { user_type: context.user_type } } if context.user_type
        must_clauses << { term: { event_name: options[:event_name] } } if options[:event_name]
        must_clauses << { term: { event_type: options[:event_type].to_s } } if options[:event_type]
        
        if options[:since] || options[:until]
          range_clause = {}
          range_clause[:gte] = options[:since].iso8601 if options[:since]
          range_clause[:lte] = options[:until].iso8601 if options[:until]
          must_clauses << { range: { created_at: range_clause } }
        end
        
        if options[:metadata_filters]
          options[:metadata_filters].each do |key, value|
            must_clauses << { term: { "metadata.#{key}" => value } }
          end
        end
        
        if options[:path]
          must_clauses << { term: { "metadata.path" => options[:path] } }
        end
        
        if options[:method]
          must_clauses << { term: { "metadata.method" => options[:method] } }
        end
        
        if options[:status_code]
          must_clauses << { term: { "metadata.status_code" => options[:status_code] } }
        end
        
        { bool: { must: must_clauses } }
      end

      def build_sort(order_by)
        return [{ created_at: { order: "desc" } }] unless order_by
        
        field = order_by[:field]
        direction = order_by[:direction] || :desc
        [{ field => { order: direction.to_s } }]
      end
    end
  end
end

