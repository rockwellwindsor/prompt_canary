# frozen_string_literal: true

RSpec.describe PromptCanary::Prompt do
  after { PromptCanary::Prompt.reset_registry! }

  describe "registering a single version" do
    before do
      stub_const("TestPrompt", Class.new(PromptCanary::Prompt) do
        version("v1") do
          stable true
          model "claude-opus-4-7"
          system "You are a helpful assistant."
        end
      end)
    end

    it "registers one version" do
      expect(TestPrompt.versions.length).to eq(1)
    end

    it "captures the version attributes correctly" do
      v = TestPrompt.versions.first
      expect(v.name).to eq("v1")
      expect(v.model).to eq("claude-opus-4-7")
      expect(v.system).to eq("You are a helpful assistant.")
      expect(v.stable?).to be true
    end
  end
end
