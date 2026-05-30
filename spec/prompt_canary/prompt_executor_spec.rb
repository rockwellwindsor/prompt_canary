# frozen_string_literal: true

require "spec_helper"

RSpec.describe PromptCanary::PromptExecutor do
  let(:version) do
    instance_double(PromptCanary::Version, name: "v1", model: "claude-opus-4-7")
  end
  let(:telemetry) { { text: "response text", latency_ms: 120, tokens: { input: 10, output: 20 }, error: nil } }
  let(:adapter)   { instance_double(PromptCanary::Adapters::Base, call: telemetry) }
  let(:recorder)  { instance_double(PromptCanary::Recorder, record: nil) }
  let(:prompt_class) do
    klass = Class.new { include PromptCanary::Promptable }
    allow(PromptCanary::Router).to receive(:choose).with(klass, {}).and_return(version)
    klass
  end

  subject(:executor) do
    described_class.new(prompt_class: prompt_class, adapter: adapter, recorder: recorder)
  end

  describe "#call" do
    it "returns a Result" do
      expect(executor.call(user_message: "Go.")).to be_a(PromptCanary::Result)
    end

    it "sets text from the adapter response" do
      expect(executor.call(user_message: "Go.").text).to eq("response text")
    end

    it "sets the version used" do
      expect(executor.call(user_message: "Go.").version_used).to eq("v1")
    end

    it "records telemetry" do
      executor.call(user_message: "Go.")
      expect(recorder).to have_received(:record).with(
        prompt: anything, version: version, telemetry: telemetry
      )
    end

    context "when the adapter returns an error" do
      let(:error) { StandardError.new("API failure") }
      let(:telemetry) { { text: nil, latency_ms: 50, tokens: nil, error: error } }

      it "returns a Result with nil text and the error" do
        result = executor.call(user_message: "Go.")
        expect(result.text).to be_nil
        expect(result.error).to eq(error)
      end
    end
  end
end
