# frozen_string_literal: true

require "spec_helper"

module ActiveJob
  class Base
    def self.queue_as(_name); end
  end
end

require "prompt_canary/monitor_job"

RSpec.describe PromptCanary::MonitorJob do
  before do
    PromptCanary.configure do |c|
      c.adapter = :anthropic
      c.storage = :memory
    end
  end

  after { PromptCanary.reset_configuration! }

  it "is an ActiveJob::Base subclass" do
    expect(described_class.superclass).to eq(ActiveJob::Base)
  end

  describe "#perform" do
    let(:prompt_a) { Class.new { include PromptCanary::Promptable } }
    let(:prompt_b) { Class.new { include PromptCanary::Promptable } }
    let(:monitor)  { instance_double(PromptCanary::Monitor, evaluate: nil) }

    before do
      allow(PromptCanary::Monitor).to receive(:new).and_return(monitor)
    end

    it "evaluates every registered prompt" do
      # registered automatically via include
      _ = prompt_a
      _ = prompt_b

      described_class.new.perform

      expect(monitor).to have_received(:evaluate).with(prompt_a)
      expect(monitor).to have_received(:evaluate).with(prompt_b)
    end

    it "does nothing when no prompts are registered" do
      PromptCanary.reset_configuration!
      PromptCanary.configure do |c|
        c.adapter = :anthropic
        c.storage = :memory
      end

      described_class.new.perform

      expect(monitor).not_to have_received(:evaluate)
    end
  end
end
