# frozen_string_literal: true

module PromptCanary
  # rubocop:disable Metrics/ModuleLength
  module Deployment
    def set_canary(prompt_class, version_name, percent)
      assert_valid_canary_percent!(percent)
      assert_version_registered!(prompt_class, version_name)

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
      assert_version_registered!(prompt_class, version_name)

      if ar_storage?
        require "prompt_canary/storage/active_record_adapter"
        prev_primary = effective_primary_name(prompt_class)
        prev_status  = current_version_status(prompt_class, version_name)
        override = PrimaryOverride.find_or_initialize_by(prompt: prompt_class.name)
        override.created_at ||= Time.now
        override.update!(version: version_name)
        record_event(prompt: prompt_class.name, version: version_name, event: "promoted",
                     previous_status: prev_status, new_status: "primary",
                     reason: reason, triggered_by: "manual")
        record_superseded_event(prompt_class, prev_primary, version_name)
      else
        prompt_class.promote_to_primary!(version_name)
      end
      publish("prompt_canary.promoted", prompt: prompt_class.name, version: version_name, reason: reason)
    end

    def demote(prompt_class, version_name, reason: nil, triggered_by: "manual",
               triggering_metric: nil, triggering_value: nil, triggering_threshold: nil)
      assert_can_demote_primary!(prompt_class, version_name)

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

    def record_superseded_event(prompt_class, prev_primary, promoted_name)
      return unless prev_primary && prev_primary != promoted_name

      record_event(prompt: prompt_class.name, version: prev_primary, event: "superseded",
                   previous_status: "primary", new_status: "candidate", triggered_by: "manual")
    end

    def current_version_status(prompt_class, version_name)
      return "primary" if effective_primary_name(prompt_class) == version_name
      return "demoted" if RolloutOverride.where(
        prompt: prompt_class.name, version: version_name, rollout_override: 0
      ).exists?

      "candidate"
    rescue ::ActiveRecord::ConnectionNotEstablished, ::ActiveRecord::StatementInvalid
      "candidate"
    end

    def assert_version_registered!(prompt_class, version_name)
      return if prompt_class.versions.any? { |v| v.name == version_name }

      raise UnknownVersionError, "#{version_name.inspect} is not a registered version of #{prompt_class}"
    end

    def assert_valid_canary_percent!(percent)
      raise ArgumentError, "percent must be positive — use `demote` to stop traffic" if percent.zero?
    end

    def assert_can_demote_primary!(prompt_class, version_name)
      return unless effective_primary_name(prompt_class) == version_name
      return unless no_viable_candidate?(prompt_class, version_name)

      raise CannotDemotePrimaryError,
            "Cannot demote #{version_name.inspect} — primary version with no viable " \
            "candidate. Promote another version first."
    end

    def effective_primary_name(prompt_class)
      if ar_storage? && defined?(PromptCanary::PrimaryOverride)
        override = PrimaryOverride.find_by(prompt: prompt_class.name)
        return override.version if override
      end
      prompt_class.primary_version.name
    rescue ::ActiveRecord::ConnectionNotEstablished, ::ActiveRecord::StatementInvalid
      prompt_class.primary_version.name
    end

    def no_viable_candidate?(prompt_class, version_name)
      others = prompt_class.versions.reject { |v| v.name == version_name }
      return true if others.empty?

      if ar_storage?
        require "prompt_canary/storage/active_record_adapter"
        others.all? do |v|
          RolloutOverride.where(prompt: prompt_class.name, version: v.name, rollout_override: 0).exists?
        end
      else
        others.all?(&:demoted?)
      end
    end

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
  # rubocop:enable Metrics/ModuleLength
end
