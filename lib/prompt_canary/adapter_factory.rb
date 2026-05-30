# frozen_string_literal: true

module PromptCanary
  class AdapterFactory
    REGISTRY = {
      anthropic: -> { Adapters::Anthropic.new }
    }.freeze

    def self.build(adapter_name)
      builder = REGISTRY[adapter_name]
      raise ConfigurationError, "Unknown adapter: #{adapter_name.inspect}" unless builder

      builder.call
    end
  end
end
