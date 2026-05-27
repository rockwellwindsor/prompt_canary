# frozen_string_literal: true

RSpec.describe PromptCanary::Monitor do
  let(:storage)  { PromptCanary::Storage::Memory.new }
  let(:recorder) { PromptCanary::Recorder.new(storage: storage) }

  before do
    stub_const("InvoiceExtractor", Class.new(PromptCanary::Prompt) do
      version("v1") { stable true; model "claude-opus-4-7"; system "Extract invoice data." }
      version("v2") do
        model "claude-opus-4-7"
        system "Extract invoice data."
        rollout percent: 50
        rollback_if :error_rate, greater_than: 0.05, over: 100
      end
    end)

    100.times do |i|
      storage.write(
        prompt: "InvoiceExtractor", version: "v2",
        latency_ms: 100, tokens: nil,
        error: i < 10 ? StandardError.new("fail") : nil,
        recorded_at: Time.now
      )
    end
  end

  after { PromptCanary::Prompt.reset_registry! }

  it "demotes the version when the error rate exceeds the threshold" do
    allow(PromptCanary).to receive(:demote)

    PromptCanary::Monitor.new(recorder: recorder).evaluate(InvoiceExtractor)

    expect(PromptCanary).to have_received(:demote).with(InvoiceExtractor, "v2")
  end
end
