# frozen_string_literal: true

RSpec.describe PromptCanary::Adapters::Anthropic do
  let(:version) do
    PromptCanary::Version.new(
      name: "v1",
      model: "claude-opus-4-7",
      system: "You are a helpful assistant.",
      rollout: {}
    )
  end

  let(:client) { instance_double(::Anthropic::Client) }
  let(:messages_resource) { instance_double(::Anthropic::Resources::Messages) }
  let(:adapter) { described_class.new(client: client) }

  before do
    allow(client).to receive(:messages).and_return(messages_resource)
  end

  describe "successful response mapping" do
    before do
      allow(messages_resource).to receive(:create).and_return(double(
        content: [double(text: "extracted data")],
        usage: double(input_tokens: 412, output_tokens: 89)
      ))
    end

    it "returns the response text" do
      result = adapter.call(version: version, args: { user_message: "Hello" })
      expect(result[:text]).to eq("extracted data")
    end

    it "returns token counts" do
      result = adapter.call(version: version, args: { user_message: "Hello" })
      expect(result[:tokens]).to eq({ input: 412, output: 89 })
    end

    it "returns a latency in milliseconds" do
      result = adapter.call(version: version, args: { user_message: "Hello" })
      expect(result[:latency_ms]).to be_a(Integer)
    end

    it "returns nil for error" do
      result = adapter.call(version: version, args: { user_message: "Hello" })
      expect(result[:error]).to be_nil
    end
  end

  describe "request shape" do
    it "calls the Anthropic client with the correct model, system, and messages" do
      allow(messages_resource).to receive(:create).and_return(double(
        content: [double(text: "response text")],
        usage: double(input_tokens: 10, output_tokens: 5)
      ))

      adapter.call(version: version, args: { user_message: "Hello" })

      expect(messages_resource).to have_received(:create).with(
        model: "claude-opus-4-7",
        system_: "You are a helpful assistant.",
        max_tokens: anything,
        messages: [{ role: "user", content: "Hello" }]
      )
    end
  end
end
