# frozen_string_literal: true

module PromptCanary
  module Deployment
    def set_canary(prompt_class, version_name, percent)
      unless prompt_class.versions.any? { |v| v.name == version_name }
        raise UnknownVersionError, "#{version_name.inspect} is not a registered version of #{prompt_class}"
      end

      if ar_storage?
        require "prompt_canary/storage/active_record_adapter"
        return if RolloutOverride.where(prompt: prompt_class.name, version: version_name, rollout_override: 0).exists?

        override = RolloutOverride.find_or_initialize_by(prompt: prompt_class.name, version: version_name)
        override.created_at ||= Time.now
        override.update!(rollout_override: percent)
      else
        version = prompt_class.versions.find { |v| v.name == version_name }
        version.set_rollout!(percent)
      end
    end

    def promote(prompt_class, version_name, reason: nil)
      unless prompt_class.versions.any? { |v| v.name == version_name }
        raise UnknownVersionError, "#{version_name.inspect} is not a registered version of #{prompt_class}"
      end

      if ar_storage?
        require "prompt_canary/storage/active_record_adapter"
        override = PrimaryOverride.find_or_initialize_by(prompt: prompt_class.name)
        override.created_at ||= Time.now
        override.update!(version: version_name)
      else
        prompt_class.promote_to_primary!(version_name)
      end
      publish("prompt_canary.promoted", prompt: prompt_class.name, version: version_name, reason: reason)
    end

    def demote(prompt_class, version_name, reason: nil)
      if ar_storage?
        require "prompt_canary/storage/active_record_adapter"
        override = RolloutOverride.find_or_initialize_by(prompt: prompt_class.name, version: version_name)
        override.created_at ||= Time.now
        override.update!(rollout_override: 0)
      else
        version = prompt_class.versions.find { |v| v.name == version_name }
        version&.demote!
      end
      publish("prompt_canary.demoted", prompt: prompt_class.name, version: version_name, reason: reason)
    end

    def restore(prompt_class, version_name)
      if ar_storage?
        require "prompt_canary/storage/active_record_adapter"
        RolloutOverride.where(prompt: prompt_class.name, version: version_name).delete_all
      else
        version = prompt_class.versions.find { |v| v.name == version_name }
        version&.restore!
      end
      publish("prompt_canary.restored", prompt: prompt_class.name, version: version_name)
    end

    private

    def ar_storage?
      defined?(configuration) && configuration.storage == :active_record
    end
  end
end
