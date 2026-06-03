# frozen_string_literal: true

RSpec.describe "PromptCanary.promote" do
  before do
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

  after { PromptCanary::Prompt.reset_registry! }

  it "makes the promoted version the primary" do
    PromptCanary.promote(InvoiceExtractor, "v2")

    expect(InvoiceExtractor.primary_version.name).to eq("v2")
  end

  it "does not change traffic percentages" do
    PromptCanary.promote(InvoiceExtractor, "v2")

    expect(InvoiceExtractor.versions.find { |v| v.name == "v2" }.rollout[:percent]).to eq(20)
  end

  it "raises UnknownVersionError for an unregistered version name" do
    expect { PromptCanary.promote(InvoiceExtractor, "v99") }
      .to raise_error(PromptCanary::UnknownVersionError, /v99/)
  end

  it "emits a prompt_canary.promoted notification" do
    received = []
    PromptCanary.subscribe("prompt_canary.promoted") { |payload| received << payload }

    PromptCanary.promote(InvoiceExtractor, "v2")

    expect(received.length).to eq(1)
    expect(received.first[:version]).to eq("v2")
  end

  context "with active_record storage" do
    before(:context) do
      require "active_record"
      require "prompt_canary/storage/active_record_adapter"

      ::ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
      conn = ::ActiveRecord::Base.connection
      unless conn.table_exists?(:prompt_canary_calls)
        conn.create_table(:prompt_canary_calls) do |t|
          t.string :prompt, null: false
          t.string :version, null: false
          t.integer :latency_ms
          t.text :tokens
          t.text :error
          t.datetime :recorded_at, null: false
        end
      end
      unless conn.table_exists?(:prompt_canary_rollout_overrides)
        conn.create_table(:prompt_canary_rollout_overrides) do |t|
          t.string :prompt, null: false
          t.string :version, null: false
          t.integer :rollout_override, null: false
          t.datetime :created_at, null: false
        end
      end
      unless conn.table_exists?(:prompt_canary_primary_overrides)
        conn.create_table(:prompt_canary_primary_overrides) do |t|
          t.string :prompt, null: false
          t.string :version, null: false
          t.datetime :created_at, null: false
        end
        conn.add_index :prompt_canary_primary_overrides, :prompt, unique: true
      end
      unless conn.table_exists?(:prompt_canary_events)
        conn.create_table(:prompt_canary_events) do |t|
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

    it "writes a primary override record" do
      PromptCanary.promote(InvoiceExtractor, "v2")

      override = PromptCanary::PrimaryOverride.find_by(prompt: "InvoiceExtractor")
      expect(override).not_to be_nil
      expect(override.version).to eq("v2")
    end

    it "overwrites an existing primary override when promoting again" do
      PromptCanary.promote(InvoiceExtractor, "v2")
      PromptCanary.promote(InvoiceExtractor, "v1")

      expect(PromptCanary::PrimaryOverride.where(prompt: "InvoiceExtractor").count).to eq(1)
      expect(PromptCanary::PrimaryOverride.find_by(prompt: "InvoiceExtractor").version).to eq("v1")
    end

    it "router respects the DB primary override" do
      PromptCanary.promote(InvoiceExtractor, "v2")

      result = PromptCanary::Router.choose(InvoiceExtractor, {})
      expect(result.name).to eq("v2")
    end
  end
end
