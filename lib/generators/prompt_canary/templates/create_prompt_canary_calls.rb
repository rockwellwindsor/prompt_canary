class CreatePromptCanaryCalls < ActiveRecord::Migration[7.2]
  def change
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
end
