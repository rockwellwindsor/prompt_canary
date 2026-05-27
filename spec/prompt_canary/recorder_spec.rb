# frozen_string_literal: true

RSpec.describe PromptCanary::Recorder do
  subject(:recorder) { described_class.new(storage: PromptCanary::Storage::Memory.new) }

  let(:version) do
    PromptCanary::Version.new(name: "v1", model: "claude-opus-4-7", system: "s", rollout: {})
  end

  let(:telemetry) do
    {
      text: "some output",
      latency_ms: 500,
      tokens: { input: 100, output: 50 },
      error: nil
    }
  end

  describe "#record" do
    it "writes a record with the expected fields" do
      recorder.record(prompt: "InvoiceExtractor", version: version, telemetry: telemetry)

      results = recorder.storage.read_recent(prompt: "InvoiceExtractor", version: "v1", limit: 1)
      record = results.first

      expect(record[:prompt]).to eq("InvoiceExtractor")
      expect(record[:version]).to eq("v1")
      expect(record[:latency_ms]).to eq(500)
      expect(record[:tokens]).to eq({ input: 100, output: 50 })
      expect(record[:error]).to be_nil
      expect(record[:recorded_at]).to be_a(Time)
    end
  end
end
