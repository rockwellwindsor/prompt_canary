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
end
