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
end
