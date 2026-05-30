# frozen_string_literal: true

module PromptCanary
  class PromptExecutor
    def initialize(prompt_class:, adapter: nil, recorder: nil)
      @prompt_class = prompt_class
      @adapter      = adapter  || AdapterFactory.build(PromptCanary.configuration.adapter)
      @recorder     = recorder || Recorder.new(storage: StorageFactory.build(PromptCanary.configuration.storage))
    end

    def call(context: {}, **args)
      version   = Router.choose(@prompt_class, context)
      telemetry = @adapter.call(version: version, args: args)
      @recorder.record(prompt: @prompt_class.name, version: version, telemetry: telemetry)

      Result.new(
        text:         telemetry[:text],
        version_used: version.name,
        model:        version.model,
        latency_ms:   telemetry[:latency_ms],
        tokens:       telemetry[:tokens],
        error:        telemetry[:error],
        recorded_at:  Time.now
      )
    end
  end
end
