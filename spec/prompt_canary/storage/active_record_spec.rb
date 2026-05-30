# frozen_string_literal: true

require "spec_helper"
require "active_record"
require "prompt_canary/storage/active_record_adapter"

RSpec.describe PromptCanary::Storage::ActiveRecord do
  before(:context) do
    ::ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
    ::ActiveRecord::Base.connection.create_table :prompt_canary_calls do |t|
      t.string   :prompt,      null: false
      t.string   :version,     null: false
      t.integer  :latency_ms
      t.text     :tokens
      t.text     :error
      t.datetime :recorded_at, null: false
    end
    ::ActiveRecord::Base.connection.add_index(
      :prompt_canary_calls, %i[prompt version recorded_at]
    )
  end

  around do |example|
    ::ActiveRecord::Base.transaction do
      example.run
      raise ::ActiveRecord::Rollback
    end
  end

  let(:store) { described_class.new }

  it_behaves_like "a storage adapter"
end
