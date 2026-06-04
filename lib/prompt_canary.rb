# frozen_string_literal: true

module PromptCanary
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class DuplicateVersionError < Error; end
  class NoPrimaryVersionError < Error; end
  class UnknownVersionError < Error; end
  class CannotDemotePrimaryError < Error; end
  class DemotedVersionError < Error; end
end

require_relative "prompt_canary/deployment"

module PromptCanary
  class << self
    include Deployment

    def configure
      yield configuration
      configuration.validate!
    end

    def configuration
      @configuration ||= Configuration.new
    end

    def register_prompt(klass)
      registered_prompts << klass
    end

    def registered_prompts
      @registered_prompts ||= []
    end

    def reset_configuration!
      @configuration = nil
      @registered_prompts = nil
    end

    def load_prompt_classes(path, loader: method(:require))
      return unless File.directory?(path)

      Dir[File.join(path, "**", "*.rb")].sort.each { |f| loader.call(f) }
    end

    def check_storage_config!(logger)
      return unless configuration.storage == :sqlite

      logger.warn(
        "[PromptCanary] storage: :sqlite is not recommended for multi-process Rails deployments. " \
        "Run `rails generate prompt_canary:install && rails db:migrate` " \
        "and set `storage: :active_record`."
      )
    end

    def stats(prompt_class, version_name, over: 100)
      recorder = Recorder.new(storage: StorageFactory.build(configuration.storage))
      recorder.stats(prompt: prompt_class.name, version: version_name, over: over)
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

require_relative "prompt_canary/version"
require_relative "prompt_canary/configuration"
require_relative "prompt_canary/rollback_rule"
require_relative "prompt_canary/result"
require_relative "prompt_canary/version_object"
require_relative "prompt_canary/version_builder"
require_relative "prompt_canary/promptable"
require_relative "prompt_canary/prompt"
require_relative "prompt_canary/router"
require_relative "prompt_canary/adapters/base"
require_relative "prompt_canary/adapters/anthropic"
require_relative "prompt_canary/adapter_factory"
require_relative "prompt_canary/storage/memory"
require_relative "prompt_canary/storage_factory"
require_relative "prompt_canary/prompt_executor"
require_relative "prompt_canary/recorder"
require_relative "prompt_canary/monitor"
require_relative "prompt_canary/cli"
require_relative "prompt_canary/railtie" if defined?(Rails::Railtie)
require_relative "prompt_canary/engine" if defined?(Rails::Engine)
