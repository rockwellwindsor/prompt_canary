# frozen_string_literal: true

RSpec.describe PromptCanary::Storage::Memory do
  subject(:store) { described_class.new }

  let(:record) do
    {
      prompt: "InvoiceExtractor",
      version: "v1",
      text: "some output",
      latency_ms: 500,
      tokens: { input: 100, output: 50 },
      error: nil,
      recorded_at: Time.now
    }
  end

  it "returns a written record when read back" do
    store.write(record)
    results = store.read_recent(prompt: "InvoiceExtractor", version: "v1", limit: 10)
    expect(results).to include(record)
  end

  it "returns only records matching the prompt and version" do
    other_record = record.merge(version: "v2")
    store.write(record)
    store.write(other_record)
    results = store.read_recent(prompt: "InvoiceExtractor", version: "v1", limit: 10)
    expect(results.length).to eq(1)
    expect(results.first[:version]).to eq("v1")
  end

  it "respects the limit" do
    5.times { store.write(record) }
    results = store.read_recent(prompt: "InvoiceExtractor", version: "v1", limit: 3)
    expect(results.length).to eq(3)
  end
end
