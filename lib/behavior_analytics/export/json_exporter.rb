# frozen_string_literal: true

require "json"

module BehaviorAnalytics
  module Export
    class JsonExporter
      def initialize(storage_adapter)
        @storage_adapter = storage_adapter
      end

      def export(context, options = {})
        context.validate!

        events = @storage_adapter.events_for_context(context, options)
        JSON.pretty_generate(events)
      end

      def export_to_file(context, file_path, options = {})
        json_content = export(context, options)
        File.write(file_path, json_content)
        file_path
      end

      def stream_export(context, options = {}, &block)
        context.validate!

        batch_size = options[:batch_size] || 1000
        offset = 0
        first_item = true

        yield "["

        loop do
          batch_options = options.merge(limit: batch_size, offset: offset)
          events = @storage_adapter.events_for_context(context, batch_options)

          break if events.empty?

          events.each_with_index do |event, index|
            yield "," unless first_item && index == 0
            yield JSON.generate(event)
            first_item = false
          end

          offset += batch_size
          break if events.size < batch_size
        end

        yield "]"
      end
    end
  end
end

