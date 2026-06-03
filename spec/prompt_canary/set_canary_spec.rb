# frozen_string_literal: true

RSpec.describe "PromptCanary.set_canary" do
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

  it "raises UnknownVersionError for an unregistered version name" do
    expect { PromptCanary.set_canary(InvoiceExtractor, "v99", 50) }
      .to raise_error(PromptCanary::UnknownVersionError, /v99/)
  end

  it "updates the in-memory rollout percent for non-AR storage" do
    PromptCanary.set_canary(InvoiceExtractor, "v2", 50)

    version = InvoiceExtractor.versions.find { |v| v.name == "v2" }
    expect(version.rollout[:percent]).to eq(50)
  end

  it "does not change primary designation" do
    PromptCanary.set_canary(InvoiceExtractor, "v2", 100)

    expect(InvoiceExtractor.primary_version.name).to eq("v1")
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

    it "writes a rollout override record" do
      PromptCanary.set_canary(InvoiceExtractor, "v2", 50)

      override = PromptCanary::RolloutOverride.find_by(prompt: "InvoiceExtractor", version: "v2")
      expect(override).not_to be_nil
      expect(override.rollout_override).to eq(50)
    end

    it "router uses the overridden canary percentage" do
      PromptCanary.set_canary(InvoiceExtractor, "v2", 100)

      10.times do |i|
        result = PromptCanary::Router.choose(InvoiceExtractor, { call_id: i })
        expect(result.name).to eq("v2")
      end
    end

    it "demoted version gets zero traffic regardless of set_canary" do
      PromptCanary.demote(InvoiceExtractor, "v2")
      PromptCanary.set_canary(InvoiceExtractor, "v2", 100)

      10.times do |i|
        result = PromptCanary::Router.choose(InvoiceExtractor, { call_id: i })
        expect(result.name).to eq("v1")
      end
    end
  end
end
