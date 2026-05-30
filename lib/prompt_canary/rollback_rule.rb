# frozen_string_literal: true

module PromptCanary
  class RollbackRule
    attr_reader :metric, :threshold, :comparator, :window

    def initialize(metric:, threshold:, comparator:, window:)
      @metric     = metric
      @threshold  = threshold
      @comparator = comparator
      @window     = window
      freeze
    end

    def violated_by?(value)
      case comparator
      when :greater_than then value > threshold
      when :less_than    then value < threshold
      end
    end
  end
end
