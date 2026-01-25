# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

module BehaviorAnalytics
  module Hooks
    class Webhook
      attr_reader :url, :secret, :filter, :retry_count, :timeout

      def initialize(url:, secret: nil, filter: nil, retry_count: 3, timeout: 5)
        @url = URI(url)
        @secret = secret
        @filter = filter
        @retry_count = retry_count
        @timeout = timeout
        @mutex = Mutex.new
      end

      def deliver(event, context = nil)
        return unless should_deliver?(event)

        payload = build_payload(event, context)
        signature = generate_signature(payload) if @secret

        headers = {
          "Content-Type" => "application/json",
          "User-Agent" => "BehaviorAnalytics/2.0"
        }
        headers["X-Webhook-Signature"] = signature if signature

        deliver_with_retry(payload, headers)
      end

      private

      def should_deliver?(event)
        return true unless @filter

        case @filter
        when Proc
          @filter.call(event)
        when Hash
          @filter.all? { |key, value| matches?(event, key, value) }
        when Symbol, String
          event[:event_type] == @filter || event[:event_type].to_s == @filter.to_s
        else
          true
        end
      end

      def matches?(event, key, value)
        event_value = event[key.to_sym] || event[key.to_s] || get_metadata_value(event, key.to_s)
        event_value == value || event_value.to_s == value.to_s
      end

      def get_metadata_value(event, key)
        metadata = event[:metadata] || event["metadata"] || {}
        metadata[key.to_sym] || metadata[key.to_s] || metadata[key]
      end

      def build_payload(event, context)
        {
          event: event.is_a?(Hash) ? event : event.to_h,
          context: context ? (context.is_a?(Hash) ? context : context.to_h) : nil,
          timestamp: Time.now.iso8601
        }
      end

      def generate_signature(payload)
        require "openssl" unless defined?(OpenSSL)
        payload_json = JSON.generate(payload)
        OpenSSL::HMAC.hexdigest("SHA256", @secret, payload_json)
      end

      def deliver_with_retry(payload, headers)
        last_error = nil
        
        (@retry_count + 1).times do |attempt|
          begin
            http = Net::HTTP.new(@url.host, @url.port)
            http.use_ssl = @url.scheme == "https"
            http.read_timeout = @timeout
            http.open_timeout = @timeout

            request = Net::HTTP::Post.new(@url.path)
            headers.each { |key, value| request[key] = value }
            request.body = JSON.generate(payload)

            response = http.request(request)

            if response.code.to_i >= 200 && response.code.to_i < 300
              return { success: true, response_code: response.code.to_i }
            else
              last_error = "HTTP #{response.code}: #{response.message}"
            end
          rescue StandardError => e
            last_error = e.message
            sleep(calculate_backoff(attempt)) if attempt < @retry_count
          end
        end

        { success: false, error: last_error }
      end

      def calculate_backoff(attempt)
        # Exponential backoff: 1s, 2s, 4s, etc.
        2 ** attempt
      end
    end
  end
end

