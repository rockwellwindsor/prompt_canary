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

  describe "registering multiple versions" do
    before do
      stub_const("TestPrompt", Class.new(PromptCanary::Prompt) do
        version("v1") { stable true; model "m"; system "s" }
        version("v2") { model "m"; system "s"; rollout percent: 10 }
      end)
    end

    it "registers both versions" do
      expect(TestPrompt.versions.length).to eq(2)
    end

    it "preserves both version names" do
      expect(TestPrompt.versions.map(&:name)).to eq(%w[v1 v2])
    end
  end

  describe "duplicate version names" do
    it "raises DuplicateVersionError" do
      expect {
        stub_const("TestPrompt", Class.new(PromptCanary::Prompt) do
          version("v1") { stable true; model "m"; system "s" }
          version("v1") { model "m"; system "s" }
        end)
      }.to raise_error(PromptCanary::DuplicateVersionError)
    end
  end

  describe ".stable_version" do
    it "returns the version marked stable" do
      stub_const("TestPrompt", Class.new(PromptCanary::Prompt) do
        version("v1") { stable true; model "m"; system "s" }
        version("v2") { model "m"; system "s"; rollout percent: 10 }
      end)
      expect(TestPrompt.stable_version.name).to eq("v1")
    end

    it "raises NoStableVersionError when no version is stable" do
      stub_const("TestPrompt", Class.new(PromptCanary::Prompt) do
        version("v1") { model "m"; system "s" }
      end)
      expect { TestPrompt.stable_version }.to raise_error(PromptCanary::NoStableVersionError)
    end

    it "raises AmbiguousStableVersionError when two versions are stable" do
      stub_const("TestPrompt", Class.new(PromptCanary::Prompt) do
        version("v1") { stable true; model "m"; system "s" }
        version("v2") { stable true; model "m"; system "s" }
      end)
      expect { TestPrompt.stable_version }.to raise_error(PromptCanary::AmbiguousStableVersionError)
    end
  end
end
