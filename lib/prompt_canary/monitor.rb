# frozen_string_literal: true

module PromptCanary
  class Monitor
    def initialize(recorder:)
      @recorder = recorder
    end

    def evaluate(prompt_class)
      prompt_class.versions.each do |version|
        version.rollback_rules.each do |rule|
          value = @recorder.public_send(rule.metric,
            prompt: prompt_class.name,
            version: version.name,
            over: rule.window)

          PromptCanary.demote(prompt_class, version.name) if rule.violated_by?(value)
        end
      end
    end
  end
end
