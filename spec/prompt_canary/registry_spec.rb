# frozen_string_literal: true

require "spec_helper"

RSpec.describe "PromptCanary prompt registry" do
  after { PromptCanary.reset_configuration! }

  it "registers a class automatically when it includes Promptable" do
    klass = Class.new { include PromptCanary::Promptable }
    expect(PromptCanary.registered_prompts).to include(klass)
  end

  it "accumulates multiple registered classes" do
    a = Class.new { include PromptCanary::Promptable }
    b = Class.new { include PromptCanary::Promptable }
    expect(PromptCanary.registered_prompts).to include(a, b)
  end

  it "clears the registry when reset_configuration! is called" do
    Class.new { include PromptCanary::Promptable }
    PromptCanary.reset_configuration!
    expect(PromptCanary.registered_prompts).to be_empty
  end
end
