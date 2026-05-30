# frozen_string_literal: true

require "spec_helper"

RSpec.describe PromptCanary::AdapterFactory do
  describe ".build" do
    it "returns an Anthropic adapter for :anthropic" do
      expect(described_class.build(:anthropic)).to be_a(PromptCanary::Adapters::Anthropic)
    end

    it "raises ConfigurationError for an unknown adapter" do
      expect { described_class.build(:unknown) }
        .to raise_error(PromptCanary::ConfigurationError, /Unknown adapter/)
    end

    it "covers every symbol in Configuration::VALID_ADAPTERS" do
      PromptCanary::Configuration::VALID_ADAPTERS.each do |name|
        expect(described_class::REGISTRY).to have_key(name)
      end
    end
  end
end
