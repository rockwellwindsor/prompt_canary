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

  describe "#routes?" do
    it "returns true when the hash of the key falls within the rollout percent" do
      version = described_class.new(name: "v2", model: "m", system: "s", rollout: { percent: 100 })
      expect(version.routes?("any-key")).to be true
    end

    it "returns false when rollout percent is zero" do
      version = described_class.new(name: "v2", model: "m", system: "s", rollout: { percent: 0 })
      expect(version.routes?("any-key")).to be false
    end

    it "returns false when there is no rollout" do
      version = described_class.new(name: "v1", model: "m", system: "s", rollout: {})
      expect(version.routes?("any-key")).to be false
    end
  end

  describe "#system_for" do
    it "returns the system string when system is a static string" do
      version = described_class.new(name: "v1", model: "m", system: "static text", rollout: {})
      expect(version.system_for({})).to eq("static text")
    end

    it "ignores args when system is a static string" do
      version = described_class.new(name: "v1", model: "m", system: "static text", rollout: {})
      expect(version.system_for(description: "ignored")).to eq("static text")
    end

    it "calls the block with args when system is a proc" do
      version = described_class.new(
        name: "v1", model: "m",
        system: ->(args) { "Goal: #{args[:goal]}" },
        rollout: {}
      )
      expect(version.system_for(goal: "Run a 5k")).to eq("Goal: Run a 5k")
    end

    it "passes the full args hash to the block" do
      version = described_class.new(
        name: "v1", model: "m",
        system: ->(args) { args.keys.map(&:to_s).join(",") },
        rollout: {}
      )
      expect(version.system_for(a: 1, b: 2)).to eq("a,b")
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
