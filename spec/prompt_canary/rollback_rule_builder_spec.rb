# frozen_string_literal: true

RSpec.describe "rollback_if DSL" do
  it "builds a RollbackRule for greater_than" do
    stub_const("TestPrompt", Class.new do
      include PromptCanary::Promptable
      version("v1") do
        model "m"
        system "s"
        rollback_if :error_rate, greater_than: 0.05, over: 100
      end
    end)

    rule = TestPrompt.versions.first.rollback_rules.first
    expect(rule).to be_a(PromptCanary::RollbackRule)
    expect(rule.metric).to eq(:error_rate)
    expect(rule.threshold).to eq(0.05)
    expect(rule.comparator).to eq(:greater_than)
    expect(rule.window).to eq(100)
  end

  it "builds a RollbackRule for less_than" do
    stub_const("TestPrompt", Class.new do
      include PromptCanary::Promptable
      version("v1") do
        model "m"
        system "s"
        rollback_if :eval_score, less_than: 0.75, over: 50
      end
    end)

    rule = TestPrompt.versions.first.rollback_rules.first
    expect(rule.comparator).to eq(:less_than)
    expect(rule.threshold).to eq(0.75)
  end

  it "raises ArgumentError when neither greater_than nor less_than is given" do
    expect do
      stub_const("TestPrompt", Class.new do
        include PromptCanary::Promptable
        version("v1") do
          model "m"
          system "s"
          rollback_if :error_rate, over: 100
        end
      end)
    end.to raise_error(ArgumentError, /greater_than.*less_than/i)
  end
end
