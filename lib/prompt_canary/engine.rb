# frozen_string_literal: true

require_relative "dashboard/prompts_controller"

module PromptCanary
  class Engine < Rails::Engine
    isolate_namespace PromptCanary
  end
end
