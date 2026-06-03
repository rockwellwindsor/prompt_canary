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

        prev_percent = effective_canary_percent(prompt_class, version_name)
        override = RolloutOverride.find_or_initialize_by(prompt: prompt_class.name, version: version_name)
        override.created_at ||= Time.now
        override.update!(rollout_override: percent)
        record_event(prompt: prompt_class.name, version: version_name, event: "canary_set",
                     previous_percent: prev_percent, new_percent: percent, triggered_by: "manual")
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
        record_event(prompt: prompt_class.name, version: version_name, event: "promoted",
                     previous_status: "candidate", new_status: "primary",
                     reason: reason, triggered_by: "manual")
      else
        prompt_class.promote_to_primary!(version_name)
      end
      publish("prompt_canary.promoted", prompt: prompt_class.name, version: version_name, reason: reason)
    end

    def demote(prompt_class, version_name, reason: nil, triggered_by: "manual",
               triggering_metric: nil, triggering_value: nil, triggering_threshold: nil)
      if ar_storage?
        require "prompt_canary/storage/active_record_adapter"
        prev_percent = effective_canary_percent(prompt_class, version_name)
        override = RolloutOverride.find_or_initialize_by(prompt: prompt_class.name, version: version_name)
        override.created_at ||= Time.now
        override.update!(rollout_override: 0)
        record_event(
          prompt: prompt_class.name, version: version_name, event: "demoted",
          previous_percent: prev_percent, new_percent: 0, new_status: "demoted",
          reason: reason, triggered_by: triggered_by,
          triggering_metric: triggering_metric&.to_s,
          triggering_value: triggering_value,
          triggering_threshold: triggering_threshold
        )
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
        record_event(prompt: prompt_class.name, version: version_name, event: "restored",
                     previous_status: "demoted", new_status: "candidate", triggered_by: "manual")
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

    def effective_canary_percent(prompt_class, version_name)
      existing = RolloutOverride.find_by(
        "prompt = ? AND version = ? AND rollout_override > 0",
        prompt_class.name, version_name
      )
      return existing.rollout_override if existing

      version = prompt_class.versions.find { |v| v.name == version_name }
      version&.rollout&.fetch(:percent, 0) || 0
    end

    def record_event(payload)
      return unless defined?(PromptCanary::PromptEvent)

      PromptEvent.create!(
        prompt: payload[:prompt],
        version: payload[:version],
        event: payload[:event],
        previous_percent: payload[:previous_percent],
        new_percent: payload[:new_percent],
        previous_status: payload[:previous_status],
        new_status: payload[:new_status],
        reason: payload[:reason],
        triggered_by: payload.fetch(:triggered_by, "manual"),
        triggering_metric: payload[:triggering_metric],
        triggering_value: payload[:triggering_value],
        triggering_threshold: payload[:triggering_threshold],
        recorded_at: Time.now
      )
    end
  end
end
