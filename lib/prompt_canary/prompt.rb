# frozen_string_literal: true

module PromptCanary
  class Prompt
    include Promptable

    def self.inherited(subclass)
      warn "[PromptCanary] Inheriting from PromptCanary::Prompt is deprecated. " \
           "Use `include PromptCanary::Promptable` instead."
      super
    end
  end
end
