# frozen_string_literal: true

module PromptCanary
  class Recorder
    attr_reader :storage

    def initialize(storage:)
      @storage = storage
    end

    def latency_p95(prompt:, version:, over:)
      records = @storage.read_recent(prompt: prompt, version: version, limit: over)
      return 0 if records.empty?

      latencies = records.map { |r| r[:latency_ms] }.sort
      index = (latencies.length * 0.95).ceil - 1
      latencies[index]
    end

    def error_rate(prompt:, version:, over:)
      records = @storage.read_recent(prompt: prompt, version: version, limit: over)
      return 0.0 if records.empty?

      errored = records.count { |r| !r[:error].nil? }
      (errored.to_f / records.length).round(2)
    end

    def stats(prompt:, version:, over:)
      records = @storage.read_recent(prompt: prompt, version: version, limit: over)
      return { call_count: 0, error_rate: 0.0, latency_p95: nil, last_called_at: nil } if records.empty?

      latencies   = records.map { |r| r[:latency_ms] }.compact.sort
      error_count = records.count { |r| !r[:error].nil? }
      p95_index   = (latencies.size * 0.95).ceil - 1

      {
        call_count: records.size,
        error_rate: (error_count.to_f / records.size).round(2),
        latency_p95: latencies[p95_index],
        last_called_at: records.last[:recorded_at]
      }
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
