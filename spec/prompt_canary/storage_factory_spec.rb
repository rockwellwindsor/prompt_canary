# frozen_string_literal: true

require "spec_helper"

RSpec.describe PromptCanary::StorageFactory do
  describe ".build" do
    it "returns a Memory storage for :memory" do
      expect(described_class.build(:memory)).to be_a(PromptCanary::Storage::Memory)
    end

    it "returns a SQLite storage for :sqlite" do
      expect(described_class.build(:sqlite)).to be_a(PromptCanary::Storage::SQLite)
    end

    it "raises ConfigurationError for an unknown storage" do
      expect { described_class.build(:unknown) }
        .to raise_error(PromptCanary::ConfigurationError, /Unknown storage/)
    end

    it "covers every symbol in Configuration::VALID_STORAGE" do
      PromptCanary::Configuration::VALID_STORAGE.each do |name|
        expect(described_class::REGISTRY).to have_key(name)
      end
    end
  end
end
