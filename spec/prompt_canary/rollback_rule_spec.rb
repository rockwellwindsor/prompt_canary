# frozen_string_literal: true

RSpec.describe PromptCanary::RollbackRule do
  describe "#violated_by?" do
    context "with comparator: :greater_than" do
      subject(:rule) do
        described_class.new(metric: :error_rate, threshold: 0.05, comparator: :greater_than, window: 100)
      end

      it "returns true when the value exceeds the threshold" do
        expect(rule.violated_by?(0.06)).to be true
      end

      it "returns false when the value is below the threshold" do
        expect(rule.violated_by?(0.04)).to be false
      end
    end

    context "with comparator: :less_than" do
      subject(:rule) do
        described_class.new(metric: :eval_score, threshold: 0.75, comparator: :less_than, window: 50)
      end

      it "returns true when the value is below the threshold" do
        expect(rule.violated_by?(0.70)).to be true
      end

      it "returns false when the value exceeds the threshold" do
        expect(rule.violated_by?(0.80)).to be false
      end
    end
  end

  it "is frozen after construction" do
    rule = described_class.new(metric: :error_rate, threshold: 0.05, comparator: :greater_than, window: 100)
    expect(rule).to be_frozen
  end
end
