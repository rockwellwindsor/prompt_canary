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
          name: klass.name,
          versions: klass.versions.map do |v|
            is_demoted = demoted?(klass.name, v.name)
            is_primary = klass.primary_version.name == v.name
            {
              name: v.name,
              primary: is_primary,
              demoted: is_demoted,
              active: is_primary || (!is_demoted && v.rollout.fetch(:percent, 0).positive?),
              stats: PromptCanary.stats(klass, v.name)
            }
          end
        }
      end

      def demoted?(prompt_name, version_name)
        return false unless defined?(PromptCanary::RolloutOverride)

        PromptCanary::RolloutOverride
          .where(prompt: prompt_name, version: version_name, rollout_override: 0)
          .exists?
      rescue ::ActiveRecord::ConnectionNotEstablished, ::ActiveRecord::StatementInvalid
        false
      end
    end
  end
end
