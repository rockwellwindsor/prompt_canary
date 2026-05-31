# frozen_string_literal: true

module PromptCanary
  module Dashboard
    class PromptsController < PromptCanary::ApplicationController
      attr_reader :prompts, :prompt

      def index
        @prompts = PromptCanary.registered_prompts.map { |klass| build_prompt_data(klass) }
      end

      def show
        klass = PromptCanary.registered_prompts.find { |k| k.name == params[:name] }
        head(:not_found) && return unless klass

        @prompt = build_prompt_data(klass)
      end

      private

      def build_prompt_data(klass)
        {
          name:     klass.name,
          versions: klass.versions.map do |v|
            {
              name:    v.name,
              stable:  v.stable?,
              demoted: demoted?(klass.name, v.name),
              stats:   PromptCanary.stats(klass, v.name)
            }
          end
        }
      end

      def demoted?(prompt_name, version_name)
        return false unless defined?(PromptCanary::RolloutOverride)

        PromptCanary::RolloutOverride
          .where(prompt: prompt_name, version: version_name, rollout_override: 0)
          .exists?
      rescue ::ActiveRecord::ConnectionNotEstablished
        false
      end
    end
  end
end
