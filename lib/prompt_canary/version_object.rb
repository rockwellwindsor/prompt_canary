# frozen_string_literal: true

module PromptCanary
  class Version
    attr_reader :name, :model, :system, :rollout

    def initialize(name:, model:, system:, rollout:, stable: false)
      @name = name
      @model = model
      @system = system
      @rollout = rollout
      @stable = stable
    end

    def stable?
      @stable
    end

    def partial_rollout?
      rollout.fetch(:percent, 0) > 0
    end
  end
end
