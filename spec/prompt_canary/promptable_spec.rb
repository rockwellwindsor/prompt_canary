# frozen_string_literal: true

RSpec.describe PromptCanary::Promptable do
  let(:prompt_class) do
    Class.new { include PromptCanary::Promptable }
  end

  after { prompt_class.reset_registry! }

  it "adds DSL class methods to the including class" do
    expect(prompt_class).to respond_to(:version)
    expect(prompt_class).to respond_to(:versions)
    expect(prompt_class).to respond_to(:stable_version)
    expect(prompt_class).to respond_to(:reset_registry!)
  end

  it "registers a version via the DSL" do
    prompt_class.version("v1") { stable true; model "claude-3-haiku-20240307"; system "You help." }
    expect(prompt_class.versions.length).to eq(1)
    expect(prompt_class.versions.first.name).to eq("v1")
  end

  it "raises DuplicateVersionError for duplicate version names" do
    prompt_class.version("v1") { stable true; model "m"; system "s" }
    expect {
      prompt_class.version("v1") { stable true; model "m"; system "s" }
    }.to raise_error(PromptCanary::DuplicateVersionError)
  end

  it "returns the stable version" do
    prompt_class.version("v1") { stable true; model "m"; system "s" }
    expect(prompt_class.stable_version.name).to eq("v1")
  end
end
