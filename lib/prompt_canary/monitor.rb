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

          next unless rule.violated_by?(value)

          PromptCanary.demote(
            prompt_class, version.name,
            triggered_by: "monitor",
            triggering_metric: rule.metric.to_s,
            triggering_value: value,
            triggering_threshold: rule.threshold
          )
        end
      end
    end
  end
end
