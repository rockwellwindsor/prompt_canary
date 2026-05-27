# frozen_string_literal: true

module PromptCanary
  class Prompt
    class VersionBuilder
      attr_reader :_name, :_model, :_system, :_stable, :_rollout

      def initialize(name)
        @_name = name
        @_stable = false
        @_rollout = {}
      end

      def stable(value)
        @_stable = value
      end

      def rollout(value)
        @_rollout = value
      end

      def model(value)
        @_model = value
      end

      def system(value)
        @_system = value
      end

      def build
        Version.new(
          name: _name,
          model: _model,
          system: _system,
          rollout: _rollout,
          stable: _stable
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

      def reset_registry!
        @versions = []
      end
    end
  end
end
