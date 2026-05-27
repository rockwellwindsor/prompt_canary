# frozen_string_literal: true

RSpec.describe PromptCanary::Configuration do
  after { PromptCanary.reset_configuration! }

  describe "adapter configuration" do
    it "stores the adapter" do
      PromptCanary.configure { |c| c.adapter = :anthropic }
      expect(PromptCanary.configuration.adapter).to eq(:anthropic)
    end

    it "raises ConfigurationError for unknown adapters" do
      expect {
        PromptCanary.configure { |c| c.adapter = :unknown }
      }.to raise_error(PromptCanary::ConfigurationError, /unknown adapter/i)
    end
  end
end
