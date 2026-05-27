# frozen_string_literal: true

module PromptCanary
  class Recorder
    attr_reader :storage

    def initialize(storage:)
      @storage = storage
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
