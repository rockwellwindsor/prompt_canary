# frozen_string_literal: true

RSpec.describe PromptCanary::Prompt do
  it "includes Promptable" do
    expect(PromptCanary::Prompt.ancestors).to include(PromptCanary::Promptable)
  end

  it "warns when subclassed" do
    expect { Class.new(PromptCanary::Prompt) }.to output(/deprecated.*Promptable/i).to_stderr
  end
end
