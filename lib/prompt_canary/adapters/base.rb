# frozen_string_literal: true

module PromptCanary
  module Adapters
    class Base
      def call(version:, args:)
        raise NotImplementedError, "#{self.class} must implement #call(version:, args:) to handle prompt execution"
      end
    end
  end
end
