# frozen_string_literal: true

module PromptCanary
  class VersionBuilder
    attr_reader :_name, :_model, :_system, :_stable, :_rollout

    def initialize(name)
      @_name = name
      @_stable = false
      @_rollout = {}
      @_rollback_rules = []
    end

    def stable(value)
      @_stable = value
    end

    def rollout(value)
      @_rollout = value
    end

    def rollout_to(&block)
      @_predicate = block
    end

    def rollback_if(metric, over:, greater_than: nil, less_than: nil)
      comparator = if greater_than
                     :greater_than
                   elsif less_than
                     :less_than
                   else
                     raise ArgumentError, "rollback_if requires greater_than: or less_than:"
                   end
      threshold = greater_than || less_than
      @_rollback_rules << RollbackRule.new(metric: metric, threshold: threshold, comparator: comparator, window: over)
    end

    def model(value)
      @_model = value
    end

    def system(value = nil, &block)
      @_system = block || value
    end

    def build
      Version.new(
        name: _name,
        model: _model,
        system: _system,
        rollout: _rollout,
        stable: _stable,
        predicate: @_predicate,
        rollback_rules: @_rollback_rules
      )
    end
  end
end
