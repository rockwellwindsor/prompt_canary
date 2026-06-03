# frozen_string_literal: true

module PromptCanary
  module Promptable
    def self.included(base)
      base.extend(ClassMethods)
      PromptCanary.register_prompt(base)
    end

    module ClassMethods
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

      def primary_version
        raise NoPrimaryVersionError, "#{self} has no versions registered" if versions.empty?

        versions.first
      end

      def call(context: {}, adapter: nil, recorder: nil, **args)
        PromptExecutor.new(prompt_class: self, adapter: adapter, recorder: recorder)
                      .call(context: context, **args)
      end

      def reset_registry!
        @versions = []
      end
    end
  end
end
