# frozen_string_literal: true

require "zlib"

module PromptCanary
  class Version
    attr_reader :name, :model, :system, :rollout

    def initialize(name:, model:, system:, rollout:, stable: false, predicate: nil)
      @name = name
      @model = model
      @system = system
      @rollout = rollout
      @stable = stable
      @predicate = predicate
    end

    def stable?
      @stable
    end

    def has_predicate?
      !@predicate.nil?
    end

    def matches_predicate?(context)
      return false unless @predicate

      @predicate.call(context)
    rescue StandardError
      false
    end

    def partial_rollout?
      rollout.fetch(:percent, 0) > 0
    end

    def routes?(key)
      roll = Zlib.crc32(key.to_s) % 100
      roll < rollout.fetch(:percent, 0)
    end
  end
end
