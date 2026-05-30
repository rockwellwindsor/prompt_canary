# frozen_string_literal: true

module PromptCanary
  class Prompt
    class VersionBuilder
      attr_reader :_name, :_model, :_system, :_stable, :_rollout

      def initialize(name)
        @_name = name
        @_stable = false
        @_rollout = {}
        @_rollback_rules = []
      end

      def stable(value)
        @_stable = value
      end

      def rollout(value)
        @_rollout = value
      end

      def rollout_to(&block)
        @_predicate = block
      end

      def rollback_if(metric, greater_than: nil, less_than: nil, over:)
        comparator = if greater_than
                       :greater_than
                     elsif less_than
                       :less_than
                     else
                       raise ArgumentError, "rollback_if requires greater_than: or less_than:"
                     end
        threshold = greater_than || less_than
        @_rollback_rules << RollbackRule.new(metric: metric, threshold: threshold, comparator: comparator, window: over)
      end

      def model(value)
        @_model = value
      end

      def system(value = nil, &block)
        @_system = block || value
      end

      def build
        Version.new(
          name: _name,
          model: _model,
          system: _system,
          rollout: _rollout,
          stable: _stable,
          predicate: @_predicate,
          rollback_rules: @_rollback_rules
        )
      end
    end

    class << self
      def version(name, &block)
        if versions.any? { |v| v.name == name }
          raise DuplicateVersionError, "Version #{name.inspect} is already registered on #{self}"
        end

        builder = VersionBuilder.new(name)
        builder.instance_eval(&block)
        versions << builder.build
      end

      def versions
        @versions ||= []
      end

      def stable_version
        stable = versions.select(&:stable?)
        raise AmbiguousStableVersionError, "#{self} has #{stable.length} stable versions. " \
        																		"Only one version can be marked as stable." if stable.length > 1
        raise NoStableVersionError, "#{self} has no stable version" if stable.empty?

        stable.first
      end

      def call(context: {}, adapter: nil, recorder: nil, **args)
        version   = Router.choose(self, context)
        adapter  ||= resolve_adapter
        recorder ||= Recorder.new(storage: resolve_storage)

        telemetry = adapter.call(version: version, args: args)
        recorder.record(prompt: name, version: version, telemetry: telemetry)

        Result.new(
          text: telemetry[:text],
          version_used: version.name,
          model: version.model,
          latency_ms: telemetry[:latency_ms],
          tokens: telemetry[:tokens],
          error: telemetry[:error],
          recorded_at: Time.now
        )
      end

      def reset_registry!
        @versions = []
      end

      private

      def resolve_adapter
        case PromptCanary.configuration.adapter
        when :anthropic then Adapters::Anthropic.new
        else raise ConfigurationError, "No adapter configured"
        end
      end

      def resolve_storage
        case PromptCanary.configuration.storage
        when :sqlite then Storage::SQLite.new
        when :memory then Storage::Memory.new
        else Storage::Memory.new
        end
      end
    end
  end
end
