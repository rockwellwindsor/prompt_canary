# frozen_string_literal: true

module PromptCanary
  class Configuration
    VALID_ADAPTERS = %i[anthropic].freeze

    attr_reader :adapter

    def adapter=(value)
      unless VALID_ADAPTERS.include?(value)
        raise ConfigurationError, "Unknown adapter: #{value.inspect}. Valid adapters: #{VALID_ADAPTERS.join(", ")}"
      end

      @adapter = value
    end
  end
end
