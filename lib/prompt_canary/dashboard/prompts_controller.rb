# frozen_string_literal: true

require_relative "application_controller"

module PromptCanary
  module Dashboard
    class PromptsController < ApplicationController
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
              name:   v.name,
              stable: v.stable?,
              stats:  PromptCanary.stats(klass, v.name)
            }
          end
        }
      end
    end
  end
end
