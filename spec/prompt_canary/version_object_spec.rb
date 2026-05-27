# frozen_string_literal: true

RSpec.describe PromptCanary::Version do
  describe "attributes" do
    subject(:version) do
      described_class.new(
        name: "v1",
        model: "claude-opus-4-7",
        system: "You are a helpful assistant.",
        rollout: {}
      )
    end

    it "exposes its attributes" do
      expect(version.name).to eq("v1")
      expect(version.model).to eq("claude-opus-4-7")
      expect(version.system).to eq("You are a helpful assistant.")
      expect(version.rollout).to eq({})
    end
  end

  describe "#partial_rollout?" do
    it "is true when rollout has a non-zero percent" do
      version = described_class.new(name: "v2", model: "m", system: "s", rollout: { percent: 10 })
      expect(version.partial_rollout?).to be true
    end

    it "is false when rollout is empty" do
      version = described_class.new(name: "v1", model: "m", system: "s", rollout: {})
      expect(version.partial_rollout?).to be false
    end

    it "is false when rollout percent is zero" do
      version = described_class.new(name: "v2", model: "m", system: "s", rollout: { percent: 0 })
      expect(version.partial_rollout?).to be false
    end
  end

  describe "#stable?" do
    it "is true when initialized with stable: true" do
      version = described_class.new(name: "v1", model: "m", system: "s", rollout: {}, stable: true)
      expect(version.stable?).to be true
    end

    it "is false by default" do
      version = described_class.new(name: "v1", model: "m", system: "s", rollout: {})
      expect(version.stable?).to be false
    end
  end
end
