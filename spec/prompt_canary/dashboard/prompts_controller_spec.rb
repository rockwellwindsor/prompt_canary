# frozen_string_literal: true

require "spec_helper"

unless defined?(ActionController::Base)
  module ActionController
    class Base
      def self.before_action(*); end

      def params
        @params ||= {}
      end

      def render(**); end
    end
  end
end

require_relative "../../../app/controllers/prompt_canary/application_controller"
require_relative "../../../app/controllers/prompt_canary/dashboard/prompts_controller"

RSpec.describe PromptCanary::Dashboard::PromptsController do
  before do
    PromptCanary.configure do |c|
      c.adapter = :anthropic
      c.storage = :memory
    end
  end

  after { PromptCanary.reset_configuration! }

  let(:controller) { described_class.new }

  describe "#index" do
    it "assembles a list of registered prompts with stats" do
      klass = Class.new { include PromptCanary::Promptable }
      allow(klass).to receive(:name).and_return("TestPrompt")
      klass.version("v1") do
        model "claude-opus-4-7"
      end

      controller.index

      expect(controller.prompts).to be_an(Array)
      expect(controller.prompts.first[:name]).to eq("TestPrompt")
      expect(controller.prompts.first[:versions].first[:name]).to eq("v1")
    end

    it "includes demoted: false for each version when no overrides are active" do
      klass = Class.new { include PromptCanary::Promptable }
      allow(klass).to receive(:name).and_return("TestPrompt")
      klass.version("v1") do
        model "claude-opus-4-7"
      end

      controller.index

      expect(controller.prompts.first[:versions].first[:demoted]).to eq(false)
    end

    it "includes active: true for the primary version" do
      klass = Class.new { include PromptCanary::Promptable }
      allow(klass).to receive(:name).and_return("TestPrompt")
      klass.version("v1") do
        model "claude-opus-4-7"
      end

      controller.index

      expect(controller.prompts.first[:versions].first[:active]).to eq(true)
    end

    it "includes primary: true for the first declared version" do
      klass = Class.new { include PromptCanary::Promptable }
      allow(klass).to receive(:name).and_return("TestPrompt")
      klass.version("v1") do
        model "claude-opus-4-7"
      end

      controller.index

      expect(controller.prompts.first[:versions].first[:primary]).to eq(true)
    end

    it "includes active: false for a candidate version with zero rollout" do
      klass = Class.new { include PromptCanary::Promptable }
      allow(klass).to receive(:name).and_return("TestPrompt")
      klass.version("v1") do
        model "claude-opus-4-7"
        system "s"
      end
      klass.version("v2") do
        model "claude-opus-4-7"
        system "s v2"
        rollout percent: 0
      end

      controller.index

      v2 = controller.prompts.first[:versions].find { |v| v[:name] == "v2" }
      expect(v2[:active]).to eq(false)
    end
  end

  describe "#show" do
    it "finds the prompt by name and assembles version stats" do
      klass = Class.new { include PromptCanary::Promptable }
      allow(klass).to receive(:name).and_return("TestPrompt")
      klass.version("v1") do
        model "claude-opus-4-7"
      end

      controller.instance_variable_set(:@params, { name: "TestPrompt" })
      controller.show

      expect(controller.prompt[:name]).to eq("TestPrompt")
      expect(controller.prompt[:versions].first[:stats]).to include(:call_count)
    end

    it "includes demoted: false for each version when no overrides are active" do
      klass = Class.new { include PromptCanary::Promptable }
      allow(klass).to receive(:name).and_return("TestPrompt")
      klass.version("v1") do
        model "claude-opus-4-7"
      end

      controller.instance_variable_set(:@params, { name: "TestPrompt" })
      controller.show

      expect(controller.prompt[:versions].first[:demoted]).to eq(false)
    end

    it "includes an events key with an empty array when PromptEvent is not available" do
      klass = Class.new { include PromptCanary::Promptable }
      allow(klass).to receive(:name).and_return("TestPrompt")
      klass.version("v1") { model "claude-opus-4-7" }

      controller.instance_variable_set(:@params, { name: "TestPrompt" })
      controller.show

      expect(controller.prompt).to have_key(:events)
      expect(controller.prompt[:events]).to eq([])
    end
  end
end
