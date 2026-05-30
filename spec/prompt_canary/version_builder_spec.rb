# frozen_string_literal: true

RSpec.describe PromptCanary::VersionBuilder do
  it "is accessible at the top-level namespace" do
    expect(defined?(PromptCanary::VersionBuilder)).to eq("constant")
  end

  it "builds a Version with all required fields" do
    builder = described_class.new("v1")
    builder.stable true
    builder.model "claude-3-haiku-20240307"
    builder.system "You help."
    version = builder.build
    expect(version).to be_a(PromptCanary::Version)
    expect(version.name).to eq("v1")
    expect(version.model).to eq("claude-3-haiku-20240307")
  end

  it "builds a Version with a dynamic system block" do
    builder = described_class.new("v1")
    builder.stable true
    builder.model "claude-3-haiku-20240307"
    builder.system { |args| "Hello #{args[:name]}" }
    version = builder.build
    expect(version.system_for(name: "world")).to eq("Hello world")
  end
end
