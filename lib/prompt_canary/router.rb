# frozen_string_literal: true

module PromptCanary
  class Router
    def self.choose(prompt_class, context)
      partial = prompt_class.versions.find { |v| v.partial_rollout? || v.has_predicate? }
      return prompt_class.stable_version unless partial
      return prompt_class.stable_version if demoted?(prompt_class.name, partial.name)

      return partial if partial.matches_predicate?(context)

      call_id = context[:call_id]
      return prompt_class.stable_version unless call_id

      partial.routes?(call_id) ? partial : prompt_class.stable_version
    end

    def self.demoted?(prompt_name, version_name)
      return false unless defined?(PromptCanary::RolloutOverride)

      PromptCanary::RolloutOverride
        .where(prompt: prompt_name, version: version_name, rollout_override: 0)
        .exists?
    end
    private_class_method :demoted?
  end
end
