# frozen_string_literal: true

require "spec_helper"
require "active_record"
require "prompt_canary/storage/active_record_adapter"

RSpec.describe PromptCanary::PromptEvent do
  before(:context) do
    ::ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
    conn = ::ActiveRecord::Base.connection
    conn.create_table :prompt_canary_events do |t|
      t.string  :prompt,               null: false
      t.string  :version,              null: false
      t.string  :event,                null: false
      t.integer :previous_percent
      t.integer :new_percent
      t.string  :previous_status
      t.string  :new_status
      t.text    :reason
      t.string  :triggered_by, null: false
      t.string  :triggering_metric
      t.float   :triggering_value
      t.float   :triggering_threshold
      t.datetime :recorded_at, null: false
    end
    conn.add_index :prompt_canary_events, %i[prompt version recorded_at]
  end

  around do |example|
    ::ActiveRecord::Base.transaction do
      example.run
      raise ::ActiveRecord::Rollback
    end
  end

  it "persists a manual demotion event with all fields" do
    event = described_class.create!(
      prompt: "InvoiceExtractor",
      version: "v2",
      event: "demoted",
      previous_percent: 20,
      new_percent: 0,
      previous_status: "candidate",
      new_status: "demoted",
      reason: "error rate spike",
      triggered_by: "manual",
      recorded_at: Time.now
    )

    expect(event.id).not_to be_nil
    expect(event.prompt).to eq("InvoiceExtractor")
    expect(event.version).to eq("v2")
    expect(event.event).to eq("demoted")
    expect(event.previous_percent).to eq(20)
    expect(event.new_percent).to eq(0)
    expect(event.previous_status).to eq("candidate")
    expect(event.new_status).to eq("demoted")
    expect(event.reason).to eq("error rate spike")
    expect(event.triggered_by).to eq("manual")
    expect(event.triggering_metric).to be_nil
  end

  it "persists a monitor-triggered event with metric fields" do
    event = described_class.create!(
      prompt: "InvoiceExtractor",
      version: "v2",
      event: "demoted",
      previous_percent: 20,
      new_percent: 0,
      triggered_by: "monitor",
      triggering_metric: "error_rate",
      triggering_value: 0.12,
      triggering_threshold: 0.05,
      recorded_at: Time.now
    )

    expect(event.triggering_metric).to eq("error_rate")
    expect(event.triggering_value).to be_within(0.001).of(0.12)
    expect(event.triggering_threshold).to be_within(0.001).of(0.05)
  end

  it "persists a promotion event" do
    event = described_class.create!(
      prompt: "InvoiceExtractor",
      version: "v2",
      event: "promoted",
      previous_status: "candidate",
      new_status: "primary",
      triggered_by: "manual",
      recorded_at: Time.now
    )

    expect(event.event).to eq("promoted")
    expect(event.new_status).to eq("primary")
  end
end
