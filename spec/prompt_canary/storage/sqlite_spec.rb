# frozen_string_literal: true

RSpec.describe PromptCanary::Storage::SQLite do
  subject(:store) { described_class.new(path: ":memory:") }

  it_behaves_like "a storage adapter"
end
