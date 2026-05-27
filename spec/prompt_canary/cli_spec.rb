# frozen_string_literal: true

RSpec.describe PromptCanary::CLI do
  before do
    stub_const("SomePrompt", Class.new(PromptCanary::Prompt) do
      version("v1") { stable true; model "claude-opus-4-7"; system "Extract." }
      version("v2") { model "claude-opus-4-7"; system "Extract."; rollout percent: 50 }
    end)
  end

  after { PromptCanary::Prompt.reset_registry! }

  it "demotes the named version with the given reason" do
    allow(PromptCanary).to receive(:demote)

    PromptCanary::CLI.new.run(["demote", "SomePrompt", "v2", "--reason", "high error rate"])

    expect(PromptCanary).to have_received(:demote)
      .with(SomePrompt, "v2", reason: "high error rate")
  end
end
