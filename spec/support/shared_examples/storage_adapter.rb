# frozen_string_literal: true

RSpec.shared_examples "a storage adapter" do
  let(:record) do
    {
      prompt: "InvoiceExtractor",
      version: "v1",
      latency_ms: 500,
      tokens: { input: 100, output: 50 },
      error: nil,
      recorded_at: Time.now
    }
  end

  it "returns a written record when read back" do
    store.write(record)
    results = store.read_recent(prompt: "InvoiceExtractor", version: "v1", limit: 10)
    expect(results.length).to eq(1)
    expect(results.first[:latency_ms]).to eq(500)
  end

  it "returns only records matching the prompt and version" do
    store.write(record)
    store.write(record.merge(version: "v2"))
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
