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

  describe "#latency_p95" do
    it "returns the 95th percentile latency over the window" do
      100.times do |i|
        recorder.record(
          prompt: "InvoiceExtractor",
          version: version,
          telemetry: telemetry.merge(latency_ms: i + 1)
        )
      end

      # 95th percentile of 1..100 is 95
      expect(recorder.latency_p95(prompt: "InvoiceExtractor", version: "v1", over: 100)).to eq(95)
    end
  end

  describe "#error_rate" do
    it "returns the proportion of errored calls over the window" do
      93.times { recorder.record(prompt: "InvoiceExtractor", version: version, telemetry: telemetry) }
      7.times  do
        recorder.record(prompt: "InvoiceExtractor", version: version,
                        telemetry: telemetry.merge(error: StandardError.new))
      end

      expect(recorder.error_rate(prompt: "InvoiceExtractor", version: "v1", over: 100)).to eq(0.07)
    end

    it "calculates rate over available records when fewer than the window" do
      2.times { recorder.record(prompt: "InvoiceExtractor", version: version, telemetry: telemetry) }
      recorder.record(prompt: "InvoiceExtractor", version: version,
                      telemetry: telemetry.merge(error: StandardError.new))

      expect(recorder.error_rate(prompt: "InvoiceExtractor", version: "v1", over: 100)).to eq(0.33)
    end
  end

  describe "#stats" do
    context "when no records exist" do
      it "returns zero/nil values" do
        result = recorder.stats(prompt: "InvoiceExtractor", version: "v1", over: 100)
        expect(result).to eq(
          call_count: 0,
          error_rate: 0.0,
          latency_p95: nil,
          last_called_at: nil
        )
      end
    end

    context "with a mix of successful and errored calls" do
      before do
        9.times do
          recorder.record(prompt: "InvoiceExtractor", version: version, telemetry: telemetry.merge(latency_ms: 200))
        end
        recorder.record(prompt: "InvoiceExtractor", version: version,
                        telemetry: telemetry.merge(latency_ms: 500, error: StandardError.new("fail")))
      end

      it "returns the correct call count" do
        expect(recorder.stats(prompt: "InvoiceExtractor", version: "v1", over: 100)[:call_count]).to eq(10)
      end

      it "returns the correct error rate" do
        expect(recorder.stats(prompt: "InvoiceExtractor", version: "v1", over: 100)[:error_rate]).to eq(0.1)
      end

      it "returns a last_called_at timestamp" do
        expect(recorder.stats(prompt: "InvoiceExtractor", version: "v1", over: 100)[:last_called_at]).to be_a(Time)
      end
    end

    context "latency p95" do
      it "returns the 95th percentile latency" do
        100.times do |i|
          recorder.record(
            prompt: "InvoiceExtractor",
            version: version,
            telemetry: telemetry.merge(latency_ms: i + 1)
          )
        end

        expect(recorder.stats(prompt: "InvoiceExtractor", version: "v1", over: 100)[:latency_p95]).to eq(95)
      end
    end
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
