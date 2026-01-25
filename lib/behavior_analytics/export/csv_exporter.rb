# frozen_string_literal: true

require "csv"
require "set"

module BehaviorAnalytics
  module Export
    class CsvExporter
      def initialize(storage_adapter)
        @storage_adapter = storage_adapter
      end

      def export(context, options = {})
        context.validate!

        events = @storage_adapter.events_for_context(context, options)
        return "" if events.empty?

        # Determine columns
        columns = options[:columns] || extract_columns(events)
        
        CSV.generate(headers: true) do |csv|
          csv << columns
          
          events.each do |event|
            row = columns.map do |column|
              get_value(event, column)
            end
            csv << row
          end
        end
      end

      def export_to_file(context, file_path, options = {})
        csv_content = export(context, options)
        File.write(file_path, csv_content)
        file_path
      end

      def stream_export(context, options = {}, &block)
        context.validate!

        batch_size = options[:batch_size] || 1000
        offset = 0
        first_batch = true

        loop do
          batch_options = options.merge(limit: batch_size, offset: offset)
          events = @storage_adapter.events_for_context(context, batch_options)

          break if events.empty?

          if first_batch
            columns = options[:columns] || extract_columns(events)
            yield CSV.generate_line(columns)
            first_batch = false
          end

          events.each do |event|
            columns = options[:columns] || extract_columns([event])
            row = columns.map { |col| get_value(event, col) }
            yield CSV.generate_line(row)
          end

          offset += batch_size
          break if events.size < batch_size
        end
      end

      private

      def extract_columns(events)
        return [] if events.empty?

        columns = Set.new
        events.each do |event|
          event.keys.each { |key| columns << key.to_s }
          if event[:metadata] && event[:metadata].is_a?(Hash)
            event[:metadata].keys.each { |key| columns << "metadata.#{key}" }
          end
        end

        columns.sort
      end

      def get_value(event, column)
        if column.include?(".")
          parts = column.split(".", 2)
          if parts[0] == "metadata"
            metadata = event[:metadata] || event["metadata"] || {}
            metadata[parts[1].to_sym] || metadata[parts[1].to_s] || metadata[parts[1]] || ""
          else
            event[parts[0].to_sym] || event[parts[0].to_s] || ""
          end
        else
          event[column.to_sym] || event[column.to_s] || ""
        end
      end
    end
  end
end

