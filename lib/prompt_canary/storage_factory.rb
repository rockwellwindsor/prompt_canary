# frozen_string_literal: true

module PromptCanary
  class StorageFactory
    REGISTRY = {
      memory: -> { Storage::Memory.new },
      sqlite: -> { Storage::SQLite.new },
      active_record: -> { Storage::ActiveRecord.new }
    }.freeze

    def self.build(storage_name)
      builder = REGISTRY[storage_name]
      raise ConfigurationError, "Unknown storage: #{storage_name.inspect}" unless builder

      builder.call
    end
  end
end
