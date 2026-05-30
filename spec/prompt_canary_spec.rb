# frozen_string_literal: true

RSpec.describe PromptCanary do
  before do
    PromptCanary.configure do |c|
      c.adapter = :anthropic
      c.storage = :memory
    end
  end

  after { PromptCanary.reset_configuration! }

  describe ".check_storage_config!" do
    let(:logger) { instance_double("Logger", warn: nil) }

    it "warns when storage is :sqlite" do
      PromptCanary.reset_configuration!
      PromptCanary.configure { |c| c.adapter = :anthropic; c.storage = :sqlite }
      PromptCanary.check_storage_config!(logger)
      expect(logger).to have_received(:warn).with(/active_record/)
    end

    it "does not warn when storage is :active_record" do
      PromptCanary.reset_configuration!
      PromptCanary.configure { |c| c.adapter = :anthropic; c.storage = :active_record }
      PromptCanary.check_storage_config!(logger)
      expect(logger).not_to have_received(:warn)
    end

    it "does not warn when storage is :memory" do
      PromptCanary.reset_configuration!
      PromptCanary.configure { |c| c.adapter = :anthropic; c.storage = :memory }
      PromptCanary.check_storage_config!(logger)
      expect(logger).not_to have_received(:warn)
    end
  end

  describe ".stats" do
    let(:prompt_class) do
      klass = Class.new { include PromptCanary::Promptable }
      allow(klass).to receive(:name).and_return("TestPrompt")
      klass
    end

    it "returns a stats hash for a prompt version" do
      result = PromptCanary.stats(prompt_class, "v1")
      expect(result).to include(:call_count, :error_rate, :latency_p95, :last_called_at)
    end

    it "returns zero counts when no calls have been recorded" do
      result = PromptCanary.stats(prompt_class, "v1")
      expect(result[:call_count]).to eq(0)
      expect(result[:error_rate]).to eq(0.0)
    end

    it "accepts a custom window via over:" do
      result = PromptCanary.stats(prompt_class, "v1", over: 50)
      expect(result).to include(:call_count)
    end
  end
end
