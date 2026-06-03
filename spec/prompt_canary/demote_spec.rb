# frozen_string_literal: true

RSpec.describe "PromptCanary.demote" do
  before do
    stub_const("InvoiceExtractor", Class.new(PromptCanary::Prompt) do
      version("v1") do
        model "claude-opus-4-7"
        system "Extract invoice data."
      end
      version("v2") do
        model "claude-opus-4-7"
        system "Extract invoice data."
        rollout percent: 50
      end
    end)
  end

  after { PromptCanary::Prompt.reset_registry! }

  it "sets the version's rollout percent to 0" do
    PromptCanary.demote(InvoiceExtractor, "v2")

    version = InvoiceExtractor.versions.find { |v| v.name == "v2" }
    expect(version.rollout[:percent]).to eq(0)
  end

  it "emits a prompt_canary.demoted notification" do
    received = []
    PromptCanary.subscribe("prompt_canary.demoted") { |payload| received << payload }

    PromptCanary.demote(InvoiceExtractor, "v2")

    expect(received.length).to eq(1)
    expect(received.first[:version]).to eq("v2")
  end

  context "with active_record storage" do
    before(:context) do
      require "active_record"
      require "prompt_canary/storage/active_record_adapter"

      ::ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
      ::ActiveRecord::Base.connection.create_table :prompt_canary_calls do |t|
        t.string   :prompt,      null: false
        t.string   :version,     null: false
        t.integer  :latency_ms
        t.text     :tokens
        t.text     :error
        t.datetime :recorded_at, null: false
      end
      ::ActiveRecord::Base.connection.create_table :prompt_canary_rollout_overrides do |t|
        t.string   :prompt,           null: false
        t.string   :version,          null: false
        t.integer  :rollout_override, null: false
        t.datetime :created_at,       null: false
      end
    end

    before do
      PromptCanary.configure do |c|
        c.adapter = :anthropic
        c.storage = :active_record
      end
    end

    around do |example|
      ::ActiveRecord::Base.transaction do
        example.run
        raise ::ActiveRecord::Rollback
      end
    end

    it "writes a rollout override record when demoting" do
      PromptCanary.demote(InvoiceExtractor, "v2")

      override = PromptCanary::RolloutOverride.find_by(prompt: "InvoiceExtractor", version: "v2")
      expect(override).not_to be_nil
      expect(override.rollout_override).to eq(0)
    end

    it "does not mutate the in-memory rollout when an override is written" do
      PromptCanary.demote(InvoiceExtractor, "v2")

      version = InvoiceExtractor.versions.find { |v| v.name == "v2" }
      expect(version.rollout[:percent]).to eq(50)
    end

    it "deletes the override record when restoring" do
      PromptCanary.demote(InvoiceExtractor, "v2")
      PromptCanary.restore(InvoiceExtractor, "v2")

      expect(PromptCanary::RolloutOverride.where(prompt: "InvoiceExtractor", version: "v2")).to be_empty
    end

    it "emits a prompt_canary.restored notification" do
      received = []
      PromptCanary.subscribe("prompt_canary.restored") { |payload| received << payload }

      PromptCanary.restore(InvoiceExtractor, "v2")

      expect(received.length).to eq(1)
      expect(received.first[:version]).to eq("v2")
    end
  end
end
