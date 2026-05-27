# frozen_string_literal: true

module PromptCanary
  class Router
    def self.choose(prompt_class, context)
      partial = prompt_class.versions.find { |v| v.partial_rollout? || v.has_predicate? }
      return prompt_class.stable_version unless partial

      return partial if partial.matches_predicate?(context)

      call_id = context[:call_id]
      return prompt_class.stable_version unless call_id

      partial.routes?(call_id) ? partial : prompt_class.stable_version
    end
  end
end
