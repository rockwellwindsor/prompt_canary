# frozen_string_literal: true

require_relative "monitor_job"

module PromptCanary
  class Railtie < Rails::Railtie
    initializer "prompt_canary.load_prompt_classes" do |app|
      ActiveSupport.on_load(:after_initialize) do
        PromptCanary.load_prompt_classes(Rails.root.join("app", "prompts").to_s)
      end
    end

    initializer "prompt_canary.check_storage_config" do
      ActiveSupport.on_load(:after_initialize) do
        PromptCanary.check_storage_config!(Rails.logger)
      end
    end

    initializer "prompt_canary.log_registered_prompts" do
      ActiveSupport.on_load(:after_initialize) do
        next unless PromptCanary.registered_prompts.any?

        names = PromptCanary.registered_prompts.map(&:name).join(", ")
        Rails.logger.info("[PromptCanary] Registered prompts: #{names}")
      end
    end
  end
end
