# frozen_string_literal: true

require "spec_helper"
require "active_record"
require "prompt_canary/storage/active_record_adapter"

RSpec.describe "Deployment audit events" do
  before(:context) do
    ::ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
    conn = ::ActiveRecord::Base.connection

    conn.create_table :prompt_canary_calls do |t|
      t.string :prompt, null: false
      t.string :version, null: false
      t.integer :latency_ms
      t.text :tokens
      t.text :error
      t.datetime :recorded_at, null: false
    end
    conn.create_table :prompt_canary_rollout_overrides do |t|
      t.string :prompt, null: false
      t.string :version, null: false
      t.integer :rollout_override, null: false
      t.datetime :created_at, null: false
    end
    conn.create_table :prompt_canary_primary_overrides do |t|
      t.string :prompt, null: false
      t.string :version, null: false
      t.datetime :created_at, null: false
    end
    conn.add_index :prompt_canary_primary_overrides, :prompt, unique: true
    conn.create_table :prompt_canary_events do |t|
      t.string :prompt, null: false
      t.string :version, null: false
      t.string :event, null: false
      t.integer :previous_percent
      t.integer :new_percent
      t.string :previous_status
      t.string :new_status
      t.text :reason
      t.string :triggered_by, null: false
      t.string :triggering_metric
      t.float :triggering_value
      t.float :triggering_threshold
      t.datetime :recorded_at, null: false
    end
    conn.add_index :prompt_canary_events, %i[prompt version recorded_at]
  end

  before do
    PromptCanary.configure do |c|
      c.adapter = :anthropic
      c.storage = :active_record
    end

    stub_const("InvoiceExtractor", Class.new(PromptCanary::Prompt) do
      version("v1") do
        model "claude-opus-4-7"
        system "Extract invoice data."
      end
      version("v2") do
        model "claude-opus-4-7"
        system "Extract invoice data v2."
        rollout percent: 20
      end
    end)
  end

  after do
    PromptCanary.reset_configuration!
    PromptCanary::Prompt.reset_registry!
  end

  around do |example|
    ::ActiveRecord::Base.transaction do
      example.run
      raise ::ActiveRecord::Rollback
    end
  end

  describe "promote" do
    it "writes a promoted event" do
      PromptCanary.promote(InvoiceExtractor, "v2", reason: "passed canary")

      event = PromptCanary::PromptEvent.last
      expect(event.event).to eq("promoted")
      expect(event.prompt).to eq("InvoiceExtractor")
      expect(event.version).to eq("v2")
      expect(event.new_status).to eq("primary")
      expect(event.previous_status).to eq("candidate")
      expect(event.triggered_by).to eq("manual")
      expect(event.reason).to eq("passed canary")
    end
  end

  describe "demote" do
    it "writes a demoted event for manual demotion" do
      PromptCanary.demote(InvoiceExtractor, "v2", reason: "error rate spike")

      event = PromptCanary::PromptEvent.last
      expect(event.event).to eq("demoted")
      expect(event.version).to eq("v2")
      expect(event.previous_percent).to eq(20)
      expect(event.new_percent).to eq(0)
      expect(event.new_status).to eq("demoted")
      expect(event.triggered_by).to eq("manual")
      expect(event.reason).to eq("error rate spike")
    end

    it "writes a demoted event for monitor-triggered demotion" do
      PromptCanary.demote(
        InvoiceExtractor, "v2",
        triggered_by: "monitor",
        triggering_metric: "error_rate",
        triggering_value: 0.12,
        triggering_threshold: 0.05
      )

      event = PromptCanary::PromptEvent.last
      expect(event.triggered_by).to eq("monitor")
      expect(event.triggering_metric).to eq("error_rate")
      expect(event.triggering_value).to be_within(0.001).of(0.12)
      expect(event.triggering_threshold).to be_within(0.001).of(0.05)
    end
  end

  describe "restore" do
    it "writes a restored event" do
      PromptCanary.demote(InvoiceExtractor, "v2")
      PromptCanary.restore(InvoiceExtractor, "v2")

      event = PromptCanary::PromptEvent.where(event: "restored").last
      expect(event.event).to eq("restored")
      expect(event.version).to eq("v2")
      expect(event.previous_status).to eq("demoted")
      expect(event.new_status).to eq("candidate")
      expect(event.triggered_by).to eq("manual")
    end
  end

  describe "set_canary" do
    it "writes a canary_set event" do
      PromptCanary.set_canary(InvoiceExtractor, "v2", 50)

      event = PromptCanary::PromptEvent.last
      expect(event.event).to eq("canary_set")
      expect(event.version).to eq("v2")
      expect(event.previous_percent).to eq(20)
      expect(event.new_percent).to eq(50)
      expect(event.triggered_by).to eq("manual")
    end
  end
end
