# frozen_string_literal: true

require_relative "prompt_canary/version"
require_relative "prompt_canary/configuration"
require_relative "prompt_canary/result"
require_relative "prompt_canary/version_object"
require_relative "prompt_canary/prompt"
require_relative "prompt_canary/router"
require_relative "prompt_canary/adapters/base"
require_relative "prompt_canary/adapters/anthropic"
require_relative "prompt_canary/storage/memory"
require_relative "prompt_canary/recorder"

module PromptCanary
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class DuplicateVersionError < Error; end
  class NoStableVersionError < Error; end
  class AmbiguousStableVersionError < Error; end

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
