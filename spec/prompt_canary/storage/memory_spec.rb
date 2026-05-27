# frozen_string_literal: true

RSpec.describe PromptCanary::Storage::Memory do
  subject(:store) { described_class.new }

  it_behaves_like "a storage adapter"
end
