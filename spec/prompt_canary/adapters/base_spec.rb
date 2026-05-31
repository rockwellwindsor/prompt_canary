# frozen_string_literal: true

RSpec.describe PromptCanary::Adapters::Base do
  it "raises NotImplementedError when call is invoked" do
    version = PromptCanary::Version.new(name: "v1", model: "m", system: "s", rollout: {})
    expect do
      described_class.new.call(version: version, args: {})
    end.to raise_error(NotImplementedError)
  end
end
