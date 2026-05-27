# frozen_string_literal: true

RSpec.describe "Prompt.call end-to-end" do
  let(:fake_adapter) do
    instance_double(PromptCanary::Adapters::Base).tap do |a|
      allow(a).to receive(:call).and_return(
        text: "extracted data",
        latency_ms: 300,
        tokens: { input: 50, output: 20 },
        error: nil
      )
    end
  end

  before do
    PromptCanary.configure do |c|
      c.adapter = :anthropic
      c.storage = :memory
    end

    stub_const("InvoiceExtractor", Class.new(PromptCanary::Prompt) do
      version("v1") { stable true; model "claude-opus-4-7"; system "Extract invoice data." }
    end)
  end

  after do
    PromptCanary.reset_configuration!
    PromptCanary::Prompt.reset_registry!
  end

  it "returns a Result with the expected text and version" do
    result = InvoiceExtractor.call(user_message: "Invoice #123", adapter: fake_adapter)

    expect(result).to be_a(PromptCanary::Result)
    expect(result.text).to eq("extracted data")
    expect(result.version_used).to eq("v1")
    expect(result.model).to eq("claude-opus-4-7")
  end

  it "returns a Result carrying the error when the adapter fails" do
    error = StandardError.new("service unavailable")
    failing_adapter = instance_double(PromptCanary::Adapters::Base).tap do |a|
      allow(a).to receive(:call).and_return(
        text: nil,
        latency_ms: 100,
        tokens: nil,
        error: error
      )
    end

    result = InvoiceExtractor.call(user_message: "Invoice #123", adapter: failing_adapter)

    expect(result.text).to be_nil
    expect(result.error).to eq(error)
  end

  it "records telemetry to the injected storage" do
    storage  = PromptCanary::Storage::Memory.new
    recorder = PromptCanary::Recorder.new(storage: storage)

    InvoiceExtractor.call(user_message: "Invoice #123", adapter: fake_adapter, recorder: recorder)

    records = storage.read_recent(prompt: "InvoiceExtractor", version: "v1", limit: 10)
    expect(records.length).to eq(1)
    expect(records.first[:latency_ms]).to eq(300)
    expect(records.first[:error]).to be_nil
  end
end
