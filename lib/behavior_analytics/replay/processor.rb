# frozen_string_literal: true

module BehaviorAnalytics
  module Replay
    class Processor
      def initialize(storage_adapter)
        @storage_adapter = storage_adapter
      end

      def reprocess(context, options = {})
        context.validate!

        pipeline = options[:pipeline] || []
        since = options[:since]
        until_date = options[:until]

        # Get events
        events = @storage_adapter.events_for_context(context, {
          since: since,
          until: until_date
        })

        # Apply pipeline transformations
        processed_events = events
        pipeline.each do |step|
          processed_events = apply_pipeline_step(processed_events, step)
        end

        # Save processed events back
        if options[:save_results]
          events_to_save = processed_events.map { |e| Event.new(e) }
          @storage_adapter.save_events(events_to_save)
        end

        {
          original_count: events.size,
          processed_count: processed_events.size,
          pipeline_steps: pipeline.size
        }
      end

      def enrich_events(context, enrichment_data, options = {})
        context.validate!

        since = options[:since]
        until_date = options[:until]

        events = @storage_adapter.events_for_context(context, {
          since: since,
          until: until_date
        })

        enriched_events = events.map do |event|
          enriched = event.dup
          
          enrichment_data.each do |key, value|
            if value.is_a?(Proc)
              enriched[key] = value.call(event)
            elsif value.is_a?(Hash)
              # Merge nested hash
              enriched[key] = (enriched[key] || {}).merge(value)
            else
              enriched[key] = value
            end
          end

          enriched
        end

        if options[:save_results]
          events_to_save = enriched_events.map { |e| Event.new(e) }
          @storage_adapter.save_events(events_to_save)
        end

        {
          enriched_count: enriched_events.size
        }
      end

      private

      def apply_pipeline_step(events, step)
        case step
        when Proc
          events.map { |e| step.call(e) }.compact
        when Hash
          # Apply multiple transformations
          step.reduce(events) do |result, (key, value)|
            result.map do |event|
              if value.is_a?(Proc)
                event.merge(key => value.call(event))
              else
                event.merge(key => value)
              end
            end
          end
        when Symbol, String
          # Assume it's a filter or transformation method
          events.select { |e| e.respond_to?(step) ? e.send(step) : true }
        else
          events
        end
      end
    end
  end
end

