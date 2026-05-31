# frozen_string_literal: true

require "spec_helper"

module Rails
  unless defined?(Railtie)
    class Railtie
      def self.initializer(name, **opts, &block); end
    end
  end

  unless defined?(Engine)
    class Engine < Railtie
      def self.isolate_namespace(_mod)
        @isolated = true
      end
    end
  end
end

require "prompt_canary/engine"

RSpec.describe PromptCanary::Engine do
  it "is a Rails::Engine subclass" do
    expect(described_class.superclass).to eq(Rails::Engine)
  end

  it "uses an isolated namespace" do
    expect(PromptCanary::Engine.instance_variable_get(:@isolated)).to eq(true)
  end
end
