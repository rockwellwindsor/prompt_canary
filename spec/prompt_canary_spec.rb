# frozen_string_literal: true

RSpec.describe PromptCanary do
  before do
    PromptCanary.configure do |c|
      c.adapter = :anthropic
      c.storage = :memory
    end
  end

  after { PromptCanary.reset_configuration! }

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
