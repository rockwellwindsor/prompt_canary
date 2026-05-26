# frozen_string_literal: true

RSpec.describe PromptCanary::Result do
  let(:attrs) do
    {
      text: "some output",
      version_used: "v1",
      model: "claude-opus-4-7",
      latency_ms: 1240,
      tokens: { input: 412, output: 89 },
      error: nil,
      recorded_at: Time.now
    }
  end

  subject(:result) { described_class.new(**attrs) }

  it "exposes its attributes" do
    expect(result.text).to eq("some output")
    expect(result.version_used).to eq("v1")
    expect(result.model).to eq("claude-opus-4-7")
    expect(result.latency_ms).to eq(1240)
    expect(result.tokens).to eq({ input: 412, output: 89 })
    expect(result.error).to be_nil
    expect(result.recorded_at).to be_a(Time)
  end

  it "is frozen after construction" do
    expect(result).to be_frozen
  end
end
