# frozen_string_literal: true

module PromptCanary
  class MonitorJob < ActiveJob::Base
    queue_as :default

    def perform
      recorder = Recorder.new(storage: StorageFactory.build(PromptCanary.configuration.storage))
      monitor  = Monitor.new(recorder: recorder)
      PromptCanary.registered_prompts.each { |klass| monitor.evaluate(klass) }
    end
  end
end
