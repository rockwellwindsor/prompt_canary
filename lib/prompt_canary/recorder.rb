# frozen_string_literal: true

module PromptCanary
  class Recorder
    attr_reader :storage

    def initialize(storage:)
      @storage = storage
    end

    def error_rate(prompt:, version:, over:)
      records = @storage.read_recent(prompt: prompt, version: version, limit: over)
      return 0.0 if records.empty?

      errored = records.count { |r| !r[:error].nil? }
      (errored.to_f / records.length).round(2)
    end

    def record(prompt:, version:, telemetry:)
      @storage.write(
        prompt: prompt,
        version: version.name,
        latency_ms: telemetry[:latency_ms],
        tokens: telemetry[:tokens],
        error: telemetry[:error],
        recorded_at: Time.now
      )
    end
  end
end
