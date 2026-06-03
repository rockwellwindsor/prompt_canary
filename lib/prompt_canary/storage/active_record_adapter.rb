# frozen_string_literal: true

require "active_record"
require "json"

module PromptCanary
  class Call < ::ActiveRecord::Base
    self.table_name = "prompt_canary_calls"
  end

  class RolloutOverride < ::ActiveRecord::Base
    self.table_name = "prompt_canary_rollout_overrides"
  end

  class PrimaryOverride < ::ActiveRecord::Base
    self.table_name = "prompt_canary_primary_overrides"
  end

  class PromptEvent < ::ActiveRecord::Base
    self.table_name = "prompt_canary_events"
  end

  module Storage
    class ActiveRecord
      def write(record)
        Call.create!(
          prompt: record[:prompt],
          version: record[:version],
          latency_ms: record[:latency_ms],
          tokens: record[:tokens]&.to_json,
          error: record[:error]&.message,
          recorded_at: record[:recorded_at]
        )
      end

      def read_recent(prompt:, version:, limit:)
        Call.where(prompt: prompt, version: version)
            .order(recorded_at: :desc)
            .limit(limit)
            .reverse
            .map { |row| deserialize(row) }
      end

      private

      def deserialize(row)
        {
          prompt: row.prompt,
          version: row.version,
          latency_ms: row.latency_ms,
          tokens: row.tokens ? JSON.parse(row.tokens, symbolize_names: true) : nil,
          error: row.error ? StandardError.new(row.error) : nil,
          recorded_at: row.recorded_at
        }
      end
    end
  end
end
