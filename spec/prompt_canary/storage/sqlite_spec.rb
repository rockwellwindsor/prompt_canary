# frozen_string_literal: true

require "prompt_canary/storage/sqlite"

RSpec.describe PromptCanary::Storage::SQLite do
  subject(:store) { described_class.new(path: ":memory:") }

  it_behaves_like "a storage adapter"
end
