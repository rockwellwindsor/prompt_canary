# frozen_string_literal: true

require "zlib"

module PromptCanary
  class Version
    attr_reader :name, :model, :system, :rollout, :rollback_rules

    def initialize(name:, model:, system:, rollout:, predicate: nil, rollback_rules: [])
      @name = name
      @model = model
      @system = system
      @rollout = rollout
      @predicate = predicate
      @rollback_rules = rollback_rules
    end

    def system_for(args = {})
      @system.respond_to?(:call) ? @system.call(args) : @system
    end

    def predicate?
      !@predicate.nil?
    end

    def matches_predicate?(context)
      return false unless @predicate

      @predicate.call(context)
    rescue StandardError
      false
    end

    def partial_rollout?
      rollout.fetch(:percent, 0).positive?
    end

    def routes?(key)
      roll = Zlib.crc32(key.to_s) % 100
      roll < rollout.fetch(:percent, 0)
    end

    def set_rollout!(percent)
      @rollout = { percent: percent }
    end

    def demoted?
      @demoted || false
    end

    def demote!
      @demoted = true
      @previous_rollout = @rollout.fetch(:percent, 0)
      @rollout = { percent: 0 }
    end

    def restore!
      @demoted = false
      @rollout = { percent: @previous_rollout || 0 }
      @previous_rollout = nil
    end
  end
end
