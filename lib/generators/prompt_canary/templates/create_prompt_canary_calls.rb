# frozen_string_literal: true

class CreatePromptCanaryTables < ActiveRecord::Migration[7.2]
  def change
    create_calls_table
    create_rollout_overrides_table
    create_primary_overrides_table
    create_events_table
  end

  private

  def create_calls_table
    create_table :prompt_canary_calls do |t|
      t.string   :prompt,      null: false
      t.string   :version,     null: false
      t.integer  :latency_ms
      t.text     :tokens
      t.text     :error
      t.datetime :recorded_at, null: false
    end
    add_index :prompt_canary_calls, %i[prompt version recorded_at]
  end

  def create_rollout_overrides_table
    create_table :prompt_canary_rollout_overrides do |t|
      t.string   :prompt,           null: false
      t.string   :version,          null: false
      t.integer  :rollout_override, null: false
      t.datetime :created_at,       null: false
    end
    add_index :prompt_canary_rollout_overrides, %i[prompt version], unique: true
  end

  def create_primary_overrides_table
    create_table :prompt_canary_primary_overrides do |t|
      t.string   :prompt,     null: false
      t.string   :version,    null: false
      t.datetime :created_at, null: false
    end
    add_index :prompt_canary_primary_overrides, :prompt, unique: true
  end

  def create_events_table
    create_table :prompt_canary_events do |t|
      t.string   :prompt,              null: false
      t.string   :version,             null: false
      t.string   :event,               null: false
      t.integer  :previous_percent
      t.integer  :new_percent
      t.string   :previous_status
      t.string   :new_status
      t.text     :reason
      t.string   :triggered_by, null: false
      t.string   :triggering_metric
      t.float    :triggering_value
      t.float    :triggering_threshold
      t.datetime :recorded_at, null: false
    end
    add_index :prompt_canary_events, %i[prompt version recorded_at]
  end
end
