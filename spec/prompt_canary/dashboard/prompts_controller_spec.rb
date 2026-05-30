# frozen_string_literal: true

require "spec_helper"

module ActionController
  class Base
    def self.before_action(*); end

    def params
      @params ||= {}
    end

    def render(**); end
  end
end unless defined?(ActionController::Base)

require "prompt_canary/dashboard/prompts_controller"

RSpec.describe PromptCanary::Dashboard::PromptsController do
  before do
    PromptCanary.configure { |c| c.adapter = :anthropic; c.storage = :memory }
  end

  after { PromptCanary.reset_configuration! }

  let(:controller) { described_class.new }

  describe "#index" do
    it "assembles a list of registered prompts with stats" do
      klass = Class.new { include PromptCanary::Promptable }
      allow(klass).to receive(:name).and_return("TestPrompt")
      klass.version("v1") { stable true; model "claude-opus-4-7" }

      controller.index

      expect(controller.prompts).to be_an(Array)
      expect(controller.prompts.first[:name]).to eq("TestPrompt")
      expect(controller.prompts.first[:versions].first[:name]).to eq("v1")
    end
  end

  describe "#show" do
    it "finds the prompt by name and assembles version stats" do
      klass = Class.new { include PromptCanary::Promptable }
      allow(klass).to receive(:name).and_return("TestPrompt")
      klass.version("v1") { stable true; model "claude-opus-4-7" }

      controller.instance_variable_set(:@params, { name: "TestPrompt" })
      controller.show

      expect(controller.prompt[:name]).to eq("TestPrompt")
      expect(controller.prompt[:versions].first[:stats]).to include(:call_count)
    end
  end
end
