# frozen_string_literal: true

RSpec.describe PromptCanary::Monitor do
  let(:storage)  { PromptCanary::Storage::Memory.new }
  let(:recorder) { PromptCanary::Recorder.new(storage: storage) }

  before do
    stub_const("InvoiceExtractor", Class.new(PromptCanary::Prompt) do
      version("v1") do
        model "claude-opus-4-7"
        system "Extract invoice data."
      end
      version("v2") do
        model "claude-opus-4-7"
        system "Extract invoice data."
        rollout percent: 50
        rollback_if :error_rate, greater_than: 0.05, over: 100
      end
    end)
  end

  after { PromptCanary::Prompt.reset_registry! }

  context "when the error rate exceeds the threshold" do
    before do
      100.times do |i|
        storage.write(
          prompt: "InvoiceExtractor", version: "v2",
          latency_ms: 100, tokens: nil,
          error: i < 10 ? StandardError.new("fail") : nil,
          recorded_at: Time.now
        )
      end
    end

    it "demotes the version" do
      allow(PromptCanary).to receive(:demote)

      PromptCanary::Monitor.new(recorder: recorder).evaluate(InvoiceExtractor)

      expect(PromptCanary).to have_received(:demote).with(InvoiceExtractor, "v2",
                                                          hash_including(triggered_by: "monitor"))
    end
  end

  context "with multiple rollback rules" do
    before do
      stub_const("InvoiceExtractor", Class.new(PromptCanary::Prompt) do
        version("v1") do
          model "claude-opus-4-7"
          system "Extract invoice data."
        end
        version("v2") do
          model "claude-opus-4-7"
          system "Extract invoice data."
          rollout percent: 50
          rollback_if :error_rate,  greater_than: 0.05, over: 100
          rollback_if :latency_p95, greater_than: 2000, over: 100
        end
      end)
    end

    context "when only the latency rule is violated" do
      before do
        100.times do
          storage.write(
            prompt: "InvoiceExtractor", version: "v2",
            latency_ms: 3000, tokens: nil, error: nil,
            recorded_at: Time.now
          )
        end
      end

      it "demotes the version" do
        allow(PromptCanary).to receive(:demote)
        PromptCanary::Monitor.new(recorder: recorder).evaluate(InvoiceExtractor)
        expect(PromptCanary).to have_received(:demote).with(InvoiceExtractor, "v2",
                                                            hash_including(triggered_by: "monitor"))
      end
    end

    context "when only the error rate rule is violated" do
      before do
        100.times do |i|
          storage.write(
            prompt: "InvoiceExtractor", version: "v2",
            latency_ms: 100, tokens: nil,
            error: i < 10 ? StandardError.new("fail") : nil,
            recorded_at: Time.now
          )
        end
      end

      it "demotes the version" do
        allow(PromptCanary).to receive(:demote)
        PromptCanary::Monitor.new(recorder: recorder).evaluate(InvoiceExtractor)
        expect(PromptCanary).to have_received(:demote).with(InvoiceExtractor, "v2",
                                                            hash_including(triggered_by: "monitor"))
      end
    end
  end

  context "when the error rate is below the threshold" do
    before do
      100.times do |i|
        storage.write(
          prompt: "InvoiceExtractor", version: "v2",
          latency_ms: 100, tokens: nil,
          error: i < 2 ? StandardError.new("fail") : nil,
          recorded_at: Time.now
        )
      end
    end

    it "does not demote the version" do
      allow(PromptCanary).to receive(:demote)

      PromptCanary::Monitor.new(recorder: recorder).evaluate(InvoiceExtractor)

      expect(PromptCanary).not_to have_received(:demote)
    end
  end
end
