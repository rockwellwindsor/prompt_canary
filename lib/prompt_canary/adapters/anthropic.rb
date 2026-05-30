# frozen_string_literal: true

require "anthropic"

module PromptCanary
  module Adapters
    class Anthropic < Base
      DEFAULT_MAX_TOKENS = 1024

      def initialize(client: ::Anthropic::Client.new)
        @client = client
      end

      def call(version:, args:)
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        response = @client.messages.create(
          model: version.model,
          system_: version.system_for(args),
          max_tokens: DEFAULT_MAX_TOKENS,
          messages: [{ role: "user", content: args[:user_message] }]
        )

        latency_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round

        {
          text: response.content.first.text,
          latency_ms: latency_ms,
          tokens: { input: response.usage.input_tokens, output: response.usage.output_tokens },
          error: nil
        }
      rescue ::Anthropic::Errors::APIError => e
        latency_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round
        { text: nil, latency_ms: latency_ms, tokens: nil, error: e }
      end
    end
  end
end
