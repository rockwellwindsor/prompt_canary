# frozen_string_literal: true

RSpec.describe "install generator migration template" do
  let(:template) do
    File.read(File.expand_path(
                "../../lib/generators/prompt_canary/templates/create_prompt_canary_calls.rb",
                __dir__
              ))
  end

  it "creates the prompt_canary_primary_overrides table" do
    expect(template).to include("create_table :prompt_canary_primary_overrides")
  end

  it "indexes prompt_canary_primary_overrides uniquely on prompt" do
    expect(template).to include("add_index :prompt_canary_primary_overrides, :prompt, unique: true")
  end

  it "creates the prompt_canary_events table" do
    expect(template).to include("create_table :prompt_canary_events")
  end

  it "indexes prompt_canary_events on [prompt, version, recorded_at]" do
    expect(template).to include("add_index :prompt_canary_events, %i[prompt version recorded_at]")
  end

  it "includes required event columns" do
    expect(template).to include(":event")
    expect(template).to include(":triggered_by")
    expect(template).to include(":previous_percent")
    expect(template).to include(":new_percent")
    expect(template).to include(":previous_status")
    expect(template).to include(":new_status")
    expect(template).to include(":triggering_metric")
    expect(template).to include(":triggering_value")
    expect(template).to include(":triggering_threshold")
  end
end
