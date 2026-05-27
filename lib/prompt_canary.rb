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
require_relative "prompt_canary/storage/sqlite"
require_relative "prompt_canary/recorder"
require_relative "prompt_canary/monitor"

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

    def demote(prompt_class, version_name)
      version = prompt_class.versions.find { |v| v.name == version_name }
      version&.demote!
      publish("prompt_canary.demoted", prompt: prompt_class.name, version: version_name)
    end

    def subscribe(event, &block)
      subscribers[event] << block
    end

    def reset_subscribers!
      @subscribers = nil
    end

    private

    def publish(event, payload = {})
      subscribers[event].each { |sub| sub.call(payload) }
    end

    def subscribers
      @subscribers ||= Hash.new { |h, k| h[k] = [] }
    end
  end
end
