# frozen_string_literal: true

require_relative "prompt_canary/version"
require_relative "prompt_canary/configuration"
require_relative "prompt_canary/result"
require_relative "prompt_canary/version_object"

module PromptCanary
  class Error < StandardError; end
  class ConfigurationError < Error; end

  class << self
    def configure
      yield configuration
    end

    def configuration
      @configuration ||= Configuration.new
    end

    def reset_configuration!
      @configuration = nil
    end
  end
end
