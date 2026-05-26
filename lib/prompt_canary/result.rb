# frozen_string_literal: true

module PromptCanary
  class Result
    attr_reader :text, :version_used, :model, :latency_ms, :tokens, :error, :recorded_at

    def initialize(text:, version_used:, model:, latency_ms:, tokens:, error:, recorded_at:)
      @text = text
      @version_used = version_used
      @model = model
      @latency_ms = latency_ms
      @tokens = tokens
      @error = error
      @recorded_at = recorded_at
      freeze
    end
  end
end
