# frozen_string_literal: true

module PromptCanary
  class Router
    def self.choose(prompt_class, context)
      prompt_class.stable_version
    end
  end
end
