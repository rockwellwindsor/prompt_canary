# frozen_string_literal: true

module PromptCanary
  class Configuration
    VALID_ADAPTERS = %i[anthropic].freeze
    VALID_STORAGE  = %i[memory sqlite].freeze

    attr_reader :adapter, :storage

    def adapter=(value)
      unless VALID_ADAPTERS.include?(value)
        raise ConfigurationError, "Unknown adapter: #{value.inspect}. Valid adapters: #{VALID_ADAPTERS.join(", ")}"
      end

      @adapter = value
    end

    def storage=(value)
      unless VALID_STORAGE.include?(value)
        raise ConfigurationError, "Unknown storage: #{value.inspect}. Valid storage: #{VALID_STORAGE.join(", ")}"
      end

      @storage = value
    end
  end
end
