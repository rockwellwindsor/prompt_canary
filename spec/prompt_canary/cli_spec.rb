# frozen_string_literal: true

RSpec.describe PromptCanary::CLI do
  before do
    stub_const("SomePrompt", Class.new(PromptCanary::Prompt) do
      version("v1") do
        stable true
        model "claude-opus-4-7"
        system "Extract."
      end
      version("v2") do
        model "claude-opus-4-7"
        system "Extract."
        rollout percent: 50
      end
    end)
  end

  after { PromptCanary::Prompt.reset_registry! }

  it "exits with a usage message when prompt_name or version_name is missing" do
    expect do
      PromptCanary::CLI.new.run(%w[demote SomePrompt])
    end.to output(/Usage:/).to_stderr.and raise_error(SystemExit)
  end

  it "exits with an error message when the prompt class does not exist" do
    expect do
      PromptCanary::CLI.new.run(%w[demote NonExistentPrompt v1])
    end.to output(/Unknown prompt class:/).to_stderr.and raise_error(SystemExit)
  end

  it "demotes the named version with the given reason" do
    allow(PromptCanary).to receive(:demote)

    PromptCanary::CLI.new.run(["demote", "SomePrompt", "v2", "--reason", "high error rate"])

    expect(PromptCanary).to have_received(:demote)
      .with(SomePrompt, "v2", reason: "high error rate")
  end
end
