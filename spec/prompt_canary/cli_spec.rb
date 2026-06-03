# frozen_string_literal: true

RSpec.describe PromptCanary::CLI do
  before do
    stub_const("SomePrompt", Class.new(PromptCanary::Prompt) do
      version("v1") do
        model "claude-opus-4-7"
        system "Extract."
      end
      version("v2") do
        model "claude-opus-4-7"
        system "Extract."
        rollout percent: 50
      end
    end)
  end

  after { PromptCanary::Prompt.reset_registry! }

  it "exits with a usage message when prompt_name or version_name is missing" do
    expect do
      PromptCanary::CLI.new.run(%w[demote SomePrompt])
    end.to output(/Usage:/).to_stderr.and raise_error(SystemExit)
  end

  it "exits with an error message when the prompt class does not exist" do
    expect do
      PromptCanary::CLI.new.run(%w[demote NonExistentPrompt v1])
    end.to output(/Unknown prompt class:/).to_stderr.and raise_error(SystemExit)
  end

  it "demotes the named version with the given reason" do
    allow(PromptCanary).to receive(:demote)

    PromptCanary::CLI.new.run(["demote", "SomePrompt", "v2", "--reason", "high error rate"])

    expect(PromptCanary).to have_received(:demote)
      .with(SomePrompt, "v2", reason: "high error rate")
  end

  it "promotes the named version" do
    allow(PromptCanary).to receive(:promote)

    expect { PromptCanary::CLI.new.run(%w[promote SomePrompt v2]) }.not_to raise_error

    expect(PromptCanary).to have_received(:promote).with(SomePrompt, "v2", reason: nil)
  end

  it "promotes with an optional reason" do
    allow(PromptCanary).to receive(:promote)

    expect do
      PromptCanary::CLI.new.run(["promote", "SomePrompt", "v2", "--reason", "canary passed"])
    end.not_to raise_error

    expect(PromptCanary).to have_received(:promote).with(SomePrompt, "v2", reason: "canary passed")
  end

  it "exits with a usage message when promote is missing arguments" do
    expect do
      PromptCanary::CLI.new.run(%w[promote SomePrompt])
    end.to output(/Usage:/).to_stderr.and raise_error(SystemExit)
  end

  context "history command" do
    before(:context) do
      require "active_record"
      require "prompt_canary/storage/active_record_adapter"

      ::ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
      conn = ::ActiveRecord::Base.connection
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

    around do |example|
      ::ActiveRecord::Base.transaction do
        example.run
        raise ::ActiveRecord::Rollback
      end
    end

    it "prints events for a prompt in ascending recorded_at order" do
      t1 = Time.new(2026, 6, 1, 9, 15, 0)
      t2 = Time.new(2026, 6, 1, 14, 33, 0)

      PromptCanary::PromptEvent.create!(prompt: "SomePrompt", version: "v2", event: "canary_set",
                                        previous_percent: 0, new_percent: 20,
                                        triggered_by: "manual", recorded_at: t1)
      PromptCanary::PromptEvent.create!(prompt: "SomePrompt", version: "v2", event: "promoted",
                                        previous_status: "candidate", new_status: "primary",
                                        triggered_by: "manual", recorded_at: t2)

      expect { PromptCanary::CLI.new.run(%w[history SomePrompt]) }
        .to output(/CANARY_SET.*PROMOTED/m).to_stdout
    end

    it "prints events in ascending time order" do
      t1 = Time.new(2026, 6, 1, 9, 0, 0)
      t2 = Time.new(2026, 6, 1, 10, 0, 0)

      PromptCanary::PromptEvent.create!(prompt: "SomePrompt", version: "v2", event: "promoted",
                                        triggered_by: "manual", recorded_at: t2)
      PromptCanary::PromptEvent.create!(prompt: "SomePrompt", version: "v2", event: "canary_set",
                                        previous_percent: 0, new_percent: 20,
                                        triggered_by: "manual", recorded_at: t1)

      output = capture_output { PromptCanary::CLI.new.run(%w[history SomePrompt]) }
      lines = output.strip.split("\n")
      expect(lines.first).to match(/CANARY_SET/)
      expect(lines.last).to match(/PROMOTED/)
    end

    it "filters events with --since flag" do
      old_time = Time.now - (10 * 24 * 60 * 60)
      recent_time = Time.now - (2 * 24 * 60 * 60)

      PromptCanary::PromptEvent.create!(prompt: "SomePrompt", version: "v1", event: "demoted",
                                        triggered_by: "manual", recorded_at: old_time)
      PromptCanary::PromptEvent.create!(prompt: "SomePrompt", version: "v2", event: "promoted",
                                        triggered_by: "manual", recorded_at: recent_time)

      output = capture_output { PromptCanary::CLI.new.run(%w[history SomePrompt --since 7d]) }
      expect(output).to include("PROMOTED")
      expect(output).not_to include("DEMOTED")
    end

    it "exits with a usage message when prompt name is missing" do
      expect do
        PromptCanary::CLI.new.run(%w[history])
      end.to output(/Usage:/).to_stderr.and raise_error(SystemExit)
    end

    def capture_output
      output = StringIO.new
      $stdout = output
      yield
      $stdout = STDOUT
      output.string
    end
  end
end
