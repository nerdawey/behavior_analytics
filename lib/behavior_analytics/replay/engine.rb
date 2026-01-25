# frozen_string_literal: true

module BehaviorAnalytics
  module Replay
    class Engine
      def initialize(source_adapter, target_adapter = nil)
        @source_adapter = source_adapter
        @target_adapter = target_adapter || source_adapter
      end

      def replay(context, options = {})
        context.validate!

        since = options[:since]
        until_date = options[:until]
        event_types = options[:event_types]
        event_names = options[:event_names]
        transformation = options[:transformation]

        # Get events from source
        events = @source_adapter.events_for_context(context, {
          since: since,
          until: until_date,
          event_type: event_types&.first,
          event_name: event_names&.first
        })

        # Apply additional filters
        events = filter_events(events, event_types, event_names)

        # Apply transformation if provided
        if transformation
          events = events.map { |event| apply_transformation(event, transformation) }
        end

        # Save to target adapter
        if @target_adapter != @source_adapter
          events_to_save = events.map { |e| Event.new(e) }
          @target_adapter.save_events(events_to_save)
        end

        {
          replayed_count: events.size,
          source_adapter: @source_adapter.class.name,
          target_adapter: @target_adapter.class.name
        }
      end

      def replay_with_batch(context, options = {})
        context.validate!

        batch_size = options[:batch_size] || 1000
        results = []

        # Process in batches
        offset = 0
        loop do
          batch_options = options.merge(limit: batch_size, offset: offset)
          batch = @source_adapter.events_for_context(context, batch_options)

          break if batch.empty?

          result = replay(context, options.merge(events: batch))
          results << result

          offset += batch_size
          break if batch.size < batch_size
        end

        {
          total_batches: results.size,
          total_replayed: results.sum { |r| r[:replayed_count] },
          batches: results
        }
      end

      private

      def filter_events(events, event_types, event_names)
        events.select do |event|
          matches = true
          matches &&= event_types.include?(event[:event_type]) if event_types && !event_types.empty?
          matches &&= event_names.include?(event[:event_name]) if event_names && !event_names.empty?
          matches
        end
      end

      def apply_transformation(event, transformation)
        case transformation
        when Proc
          transformation.call(event)
        when Hash
          event.merge(transformation)
        when Symbol, String
          # Assume it's a method name
          if event.respond_to?(transformation)
            event.send(transformation)
          else
            event
          end
        else
          event
        end
      end
    end
  end
end

