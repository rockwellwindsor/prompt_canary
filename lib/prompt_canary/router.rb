# frozen_string_literal: true

require "zlib"

module PromptCanary
  class Router
    def self.choose(prompt_class, context)
      partial = prompt_class.versions.find(&:partial_rollout?)
      return prompt_class.stable_version unless partial

      roll = Zlib.crc32(context.fetch(:call_id, rand).to_s) % 100
      roll < partial.rollout.fetch(:percent, 0) ? partial : prompt_class.stable_version
    end
  end
end
