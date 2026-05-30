# frozen_string_literal: true

module PromptCanary
  class Railtie < Rails::Railtie
    initializer "prompt_canary.log_registered_prompts" do
      ActiveSupport.on_load(:after_initialize) do
        next unless PromptCanary.registered_prompts.any?

        names = PromptCanary.registered_prompts.map(&:name).join(", ")
        Rails.logger.info("[PromptCanary] Registered prompts: #{names}")
      end
    end
  end
end
