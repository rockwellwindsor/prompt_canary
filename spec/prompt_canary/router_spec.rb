# frozen_string_literal: true

RSpec.describe PromptCanary::Router do
  after { PromptCanary::Prompt.reset_registry! }

  let(:prompt_class) do
    stub_const("TestPrompt", Class.new(PromptCanary::Prompt) do
      version("v1") { stable true; model "m"; system "s" }
    end)
  end

  describe "with only a stable version" do
    it "always returns the stable version regardless of context" do
      expect(PromptCanary::Router.choose(prompt_class, {})).to eq(prompt_class.stable_version)
      expect(PromptCanary::Router.choose(prompt_class, { user: { id: 42 } })).to eq(prompt_class.stable_version)
    end
  end

  describe "with percent: 0 rollout" do
    let(:prompt_class) do
      stub_const("TestPrompt", Class.new(PromptCanary::Prompt) do
        version("v1") { stable true; model "m"; system "s" }
        version("v2") { model "m"; system "s"; rollout percent: 0 }
      end)
    end

    it "always returns the stable version" do
      10.times do |i|
        result = PromptCanary::Router.choose(prompt_class, { call_id: i })
        expect(result.name).to eq("v1")
      end
    end
  end

  describe "with percent: 100 rollout" do
    let(:prompt_class) do
      stub_const("TestPrompt", Class.new(PromptCanary::Prompt) do
        version("v1") { stable true; model "m"; system "s" }
        version("v2") { model "m"; system "s"; rollout percent: 100 }
      end)
    end

    it "always returns the partial version when call_id is present" do
      10.times do |i|
        result = PromptCanary::Router.choose(prompt_class, { call_id: i })
        expect(result.name).to eq("v2")
      end
    end

    it "falls back to stable when no call_id is present" do
      result = PromptCanary::Router.choose(prompt_class, {})
      expect(result.name).to eq("v1")
    end
  end
end
