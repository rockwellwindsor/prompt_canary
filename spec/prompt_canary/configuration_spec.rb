# frozen_string_literal: true

RSpec.describe PromptCanary::Configuration do
  after { PromptCanary.reset_configuration! }

  describe "adapter configuration" do
    it "stores the adapter" do
      PromptCanary.configure { |c| c.adapter = :anthropic; c.storage = :memory }
      expect(PromptCanary.configuration.adapter).to eq(:anthropic)
    end

    it "raises ConfigurationError for unknown adapters" do
      expect {
        PromptCanary.configure { |c| c.adapter = :unknown }
      }.to raise_error(PromptCanary::ConfigurationError, /unknown adapter/i)
    end
  end

  describe "validation at configure time" do
    it "raises if no adapter is set" do
      expect {
        PromptCanary.configure { |c| c.storage = :memory }
      }.to raise_error(PromptCanary::ConfigurationError, /adapter/)
    end

    it "raises if no storage is set" do
      expect {
        PromptCanary.configure { |c| c.adapter = :anthropic }
      }.to raise_error(PromptCanary::ConfigurationError, /storage/)
    end
  end

  describe "#validate!" do
    subject(:config) { described_class.new }

    it "does not raise when adapter and storage are both set" do
      config.adapter = :anthropic
      config.storage = :memory
      expect { config.validate! }.not_to raise_error
    end

    it "raises ConfigurationError when adapter is nil" do
      config.storage = :memory
      expect { config.validate! }.to raise_error(PromptCanary::ConfigurationError, /adapter/)
    end

    it "raises ConfigurationError when storage is nil" do
      config.adapter = :anthropic
      expect { config.validate! }.to raise_error(PromptCanary::ConfigurationError, /storage/)
    end
  end
end
