# frozen_string_literal: true

RSpec.describe "PromptCanary.demote" do
  before do
    stub_const("InvoiceExtractor", Class.new(PromptCanary::Prompt) do
      version("v1") { stable true; model "claude-opus-4-7"; system "Extract invoice data." }
      version("v2") do
        model "claude-opus-4-7"
        system "Extract invoice data."
        rollout percent: 50
      end
    end)
  end

  after { PromptCanary::Prompt.reset_registry! }

  it "sets the version's rollout percent to 0" do
    PromptCanary.demote(InvoiceExtractor, "v2")

    version = InvoiceExtractor.versions.find { |v| v.name == "v2" }
    expect(version.rollout[:percent]).to eq(0)
  end

  it "emits a prompt_canary.demoted notification" do
    received = []
    PromptCanary.subscribe("prompt_canary.demoted") { |payload| received << payload }

    PromptCanary.demote(InvoiceExtractor, "v2")

    expect(received.length).to eq(1)
    expect(received.first[:version]).to eq("v2")
  end
end
