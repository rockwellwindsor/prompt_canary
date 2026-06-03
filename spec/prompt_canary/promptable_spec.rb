# frozen_string_literal: true

RSpec.describe PromptCanary::Promptable do
  let(:prompt_class) do
    Class.new { include PromptCanary::Promptable }
  end

  after { prompt_class.reset_registry! }

  it "adds DSL class methods to the including class" do
    expect(prompt_class).to respond_to(:version)
    expect(prompt_class).to respond_to(:versions)
    expect(prompt_class).to respond_to(:primary_version)
    expect(prompt_class).to respond_to(:reset_registry!)
  end

  it "treats the first declared version as primary with no flag required" do
    prompt_class.version("v1") do
      model "m"
      system "s"
    end
    prompt_class.version("v2") do
      model "m"
      system "s"
      rollout percent: 20
    end
    expect(prompt_class.primary_version.name).to eq("v1")
  end

  it "registers a version via the DSL" do
    prompt_class.version("v1") do
      model "claude-3-haiku-20240307"
      system "You help."
    end
    expect(prompt_class.versions.length).to eq(1)
    expect(prompt_class.versions.first.name).to eq("v1")
  end

  it "raises DuplicateVersionError for duplicate version names" do
    prompt_class.version("v1") do
      model "m"
      system "s"
    end
    expect do
      prompt_class.version("v1") do
        model "m"
        system "s"
      end
    end.to raise_error(PromptCanary::DuplicateVersionError)
  end

  it "raises NoPrimaryVersionError when no versions are registered" do
    expect { prompt_class.primary_version }.to raise_error(PromptCanary::NoPrimaryVersionError)
  end

  it "registers rollout percent via the DSL" do
    prompt_class.version("v1") do
      model "m"
      system "s"
    end
    prompt_class.version("v2") do
      model "m"
      system "s"
      rollout percent: 20
    end
    expect(prompt_class.versions.last.rollout).to eq({ percent: 20 })
  end

  it "registers rollback rules via the DSL" do
    prompt_class.version("v1") do
      model "m"
      system "s"
      rollback_if :error_rate, greater_than: 0.05, over: 100
    end
    rule = prompt_class.versions.first.rollback_rules.first
    expect(rule).to be_a(PromptCanary::RollbackRule)
    expect(rule.metric).to eq(:error_rate)
    expect(rule.threshold).to eq(0.05)
  end

  it "registers a dynamic system block via the DSL" do
    prompt_class.version("v1") do
      model "m"
      system { |args| "Hello #{args[:name]}" }
    end
    expect(prompt_class.versions.first.system_for(name: "world")).to eq("Hello world")
  end
end
