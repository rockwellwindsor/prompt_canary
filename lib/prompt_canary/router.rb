# frozen_string_literal: true

module PromptCanary
  class Router
    def self.choose(prompt_class, context)
      primary = db_primary(prompt_class) || prompt_class.primary_version
      partial = prompt_class.versions.find { |v| v.partial_rollout? || v.predicate? }
      return primary unless partial
      return primary if demoted?(prompt_class.name, partial.name)

      route_partial(partial, primary, context, prompt_class.name)
    end

    def self.route_partial(partial, primary, context, prompt_name)
      return partial if partial.matches_predicate?(context)

      call_id = context[:call_id]
      return primary unless call_id

      percent = canary_percent(prompt_name, partial.name, partial.rollout.fetch(:percent, 0))
      Zlib.crc32(call_id.to_s) % 100 < percent ? partial : primary
    end
    private_class_method :route_partial

    def self.canary_percent(prompt_name, version_name, default)
      return default unless defined?(PromptCanary::RolloutOverride)

      override = PromptCanary::RolloutOverride
                 .where(prompt: prompt_name, version: version_name)
                 .where("rollout_override > 0")
                 .first
      override ? override.rollout_override : default
    rescue ::ActiveRecord::ConnectionNotEstablished, ::ActiveRecord::StatementInvalid
      default
    end
    private_class_method :canary_percent

    def self.db_primary(prompt_class)
      return nil unless defined?(PromptCanary::PrimaryOverride)

      override = PromptCanary::PrimaryOverride.find_by(prompt: prompt_class.name)
      return nil unless override

      prompt_class.versions.find { |v| v.name == override.version }
    rescue ::ActiveRecord::ConnectionNotEstablished, ::ActiveRecord::StatementInvalid
      nil
    end
    private_class_method :db_primary

    def self.demoted?(prompt_name, version_name)
      return false unless defined?(PromptCanary::RolloutOverride)

      PromptCanary::RolloutOverride
        .where(prompt: prompt_name, version: version_name, rollout_override: 0)
        .exists?
    end
    private_class_method :demoted?
  end
end
