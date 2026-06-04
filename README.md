# PromptCanary

[![CI](https://github.com/rockwellwindsor/prompt_canary/actions/workflows/main.yml/badge.svg)](https://github.com/rockwellwindsor/prompt_canary/actions/workflows/main.yml)
[![Gem Version](https://badge.fury.io/rb/prompt_canary.svg)](https://badge.fury.io/rb/prompt_canary)

Canary deployments for LLM prompts in Ruby. Declare prompts as versioned Ruby classes, route traffic by percentage or predicate, record telemetry, and automatically roll back misbehaving versions when error rate or latency exceeds a configured threshold.

## Design philosophy

PromptCanary's value is in routing, telemetry, and rollback — not in where your prompt text lives. You can declare versions directly in Ruby classes, load them from database records at boot, or both. Either way the gem handles traffic splitting, call recording, and automatic demotion identically.

## Installation

```bash
bundle add prompt_canary
```

Or add to your Gemfile:

```ruby
gem "prompt_canary"
```

## Rails Setup

Run the install generator:

```bash
rails generate prompt_canary:install
```

This creates a single migration that sets up all four tables (`prompt_canary_calls`, `prompt_canary_rollout_overrides`, `prompt_canary_primary_overrides`, `prompt_canary_events`) and mounts the engine in `config/routes.rb`. Then run:

```bash
rails db:migrate
```

Add the adapter gem to your Gemfile — PromptCanary does not pull it in automatically:

```ruby
gem "anthropic"  # required when using adapter: :anthropic
```

Configure in `config/initializers/prompt_canary.rb`:

```ruby
PromptCanary.configure do |c|
  c.adapter = :anthropic      # required
  c.api_key = ENV["ANTHROPIC_API_KEY"]
  c.storage = :active_record  # recommended for Rails
end
```

## Configuration

```ruby
PromptCanary.configure do |c|
  c.adapter = :anthropic  # required
  c.storage = :sqlite     # :sqlite, :active_record, or :memory (tests)
end
```

Both `adapter` and `storage` are required. `ConfigurationError` is raised immediately if either is missing or unknown — not at first call.

Use `:active_record` in Rails apps, `:sqlite` for standalone scripts, and `:memory` in tests.

## Defining a Prompt

Include `PromptCanary::Promptable` in any class and declare versions using the DSL:

```ruby
class InvoiceExtractor
  include PromptCanary::Promptable

  version "v1" do
    model  "claude-opus-4-7"
    system "Extract structured data from this invoice."
  end
end
```

The first declared version is automatically treated as primary — no flag needed. Place prompt classes in `app/prompts/` — the Railtie loads them automatically on boot.

## Loading Prompts from the Database

Declaring versions in the class body and loading them from database records are equally supported patterns. The DSL works the same either way — it is registering `Version` objects regardless of where the data comes from.

To load from the DB, call the DSL in an initializer after the connection is established:

```ruby
# config/initializers/prompt_canary.rb
PromptCanary.configure do |c|
  c.adapter = :anthropic
  c.storage = :active_record
end

PromptRecord.all.each do |record|
  klass = record.prompt_class.constantize
  klass.version(record.version_name) do
    model  record.model
    system record.system_prompt
  end
end
```

Choose whichever approach fits your team's operational needs. The gem has no opinion on where prompt text lives.

## Calling a Prompt

```ruby
result = InvoiceExtractor.call(user_message: "Invoice #123")

result.text          # => "Here is the extracted data..."
result.version_used  # => "v1"
result.model         # => "claude-opus-4-7"
result.latency_ms    # => 312
result.tokens        # => { input: 50, output: 120 }
result.error         # => nil (or the exception if the adapter failed)
```

`call` always returns a `Result` — errors are captured in `result.error`, not raised.

## Routing Traffic

### Percentage rollout

```ruby
class InvoiceExtractor
  include PromptCanary::Promptable

  version "v1" do
    model  "claude-opus-4-7"
    system "Extract structured data from this invoice."
  end

  version "v2" do
    model  "claude-opus-4-7"
    system "Extract structured data. Return JSON."
    rollout percent: 10
  end
end
```

Pass a `call_id` in context for deterministic routing — the same `call_id` always produces the same version:

```ruby
InvoiceExtractor.call(user_message: "Invoice #123", context: { call_id: current_user.id })
```

### Predicate rollout

Route to a version based on any condition:

```ruby
version "v2" do
  model  "claude-opus-4-7"
  system "Extract structured data. Return JSON."
  rollout_to { |ctx| ctx[:user]&.fetch(:beta, false) }
end
```

```ruby
InvoiceExtractor.call(
  user_message: "Invoice #123",
  context: { user: { id: 42, beta: true } }
)
# => routes to v2 for beta users
```

If the predicate raises, the router falls back to the primary version — always safe.

## Canary Traffic

Traffic percentage and version status are independent controls. `rollout percent:` sets the initial split at declaration time. `set_canary` adjusts it at runtime without a deploy:

```ruby
PromptCanary.set_canary(InvoiceExtractor, "v2", 20)  # send 20% to v2
PromptCanary.set_canary(InvoiceExtractor, "v2", 50)  # ramp up to 50%
PromptCanary.set_canary(InvoiceExtractor, "v2", 80)  # almost there
```

Passing `0` to `set_canary` is not allowed — use `demote` to stop traffic. This keeps the audit trail unambiguous.

### Typical canary ramp

```
v1: primary,   100% traffic
v2: candidate,  20% traffic  ← set_canary(InvoiceExtractor, "v2", 20)
                              ← watch telemetry
v2: candidate,  50% traffic  ← set_canary(InvoiceExtractor, "v2", 50)
                              ← looks good
v2: primary,    50% traffic  ← promote(InvoiceExtractor, "v2")
v2: primary,   100% traffic  ← demote(InvoiceExtractor, "v1")
```

Promoting v2 changes its status only — it does not flip traffic to 100%. The traffic ramp is a separate deliberate step.

## Promote and Demote

**Status** (primary / candidate / demoted) and **traffic percentage** are separate, independent concepts.

- **promote** — marks a version as primary. The previous primary becomes a candidate. Traffic percentages are not changed.
- **demote** — sets status to demoted and zeros traffic immediately. This is the emergency brake.
- **restore** — returns a demoted version to candidate status and restores its pre-demotion traffic percentage.

```ruby
PromptCanary.promote(InvoiceExtractor, "v2")
PromptCanary.promote(InvoiceExtractor, "v2", reason: "canary passed")

PromptCanary.demote(InvoiceExtractor, "v2")
PromptCanary.demote(InvoiceExtractor, "v2", reason: "error rate spike")

PromptCanary.restore(InvoiceExtractor, "v2")
```

Attempting to demote the primary version when no other viable candidate exists raises `CannotDemotePrimaryError` — the system is never left without a route target.

All status operations write an audit event to `prompt_canary_events`.

## Auto-Rollback

Define rollback rules on a version:

```ruby
version "v2" do
  model  "claude-opus-4-7"
  system "Extract structured data. Return JSON."
  rollout percent: 10
  rollback_if :error_rate,  greater_than: 0.05, over: 100
  rollback_if :latency_p95, greater_than: 2000, over: 100
end
```

### In Rails

`PromptCanary::MonitorJob` is included and ready to queue:

```ruby
# config/initializers/prompt_canary.rb or a scheduler
PromptCanary::MonitorJob.set(wait: 5.minutes).perform_later
```

Schedule it with any background job backend (Sidekiq, GoodJob, Solid Queue, etc.).

### Standalone

```ruby
recorder = PromptCanary::Recorder.new(storage: PromptCanary::Storage::SQLite.new)
PromptCanary::Monitor.new(recorder: recorder).evaluate(InvoiceExtractor)
```

When a rule fires, `PromptCanary.demote` is called automatically — the version's rollout is zeroed, a `prompt_canary.demoted` notification is emitted, and a monitor-triggered audit event is written.

## CLI

```bash
# Promote a version to primary
prompt_canary promote InvoiceExtractor v2
prompt_canary promote InvoiceExtractor v2 --reason "canary passed"

# Demote a version (emergency stop)
prompt_canary demote InvoiceExtractor v2 --reason "error rate spike"

# Show current status and traffic for all versions
prompt_canary status InvoiceExtractor

# Show deployment history
prompt_canary history InvoiceExtractor
prompt_canary history InvoiceExtractor --since 7d
```

## Dashboard

The engine mounts a web dashboard at the path configured in your routes (default `/prompt_canary`):

- **Index** — all registered prompt classes with per-version call counts, error rates, P95 latency, and last-called timestamps
- **Show** — version breakdown with a Promote button for candidate versions, deployment history from the audit trail, and the 50 most recent calls with per-call latency, token counts, and error detail

No authentication is wired in by default. Protect the mount point with your app's existing auth if needed:

```ruby
authenticate :user, ->(u) { u.admin? } do
  mount PromptCanary::Engine, at: "/prompt_canary"
end
```

## Notifications

Subscribe to deployment events:

```ruby
PromptCanary.subscribe("prompt_canary.promoted") do |payload|
  puts "#{payload[:prompt]} #{payload[:version]} promoted"
end

PromptCanary.subscribe("prompt_canary.demoted") do |payload|
  puts "#{payload[:prompt]} #{payload[:version]} demoted — #{payload[:reason]}"
end

PromptCanary.subscribe("prompt_canary.restored") do |payload|
  puts "#{payload[:prompt]} #{payload[:version]} restored"
end
```

## Examples

Two runnable scripts are included in `examples/`. Both use a stubbed adapter and require no API key:

```bash
# Full call flow — routing, result structure, version distribution
bundle exec ruby examples/demo.rb

# Auto-rollback demo — seeds synthetic errors, runs monitor, watches demotion fire
bundle exec ruby examples/auto_rollback.rb
```

Pass `--real` to `demo.rb` to hit the Anthropic API directly (requires `ANTHROPIC_API_KEY`):

```bash
ANTHROPIC_API_KEY=sk-... bundle exec ruby examples/demo.rb --real
```

## Development

```bash
bin/setup                                    # install dependencies
bundle exec rake                             # run tests + lint
bundle exec rspec spec/foo_spec.rb:42        # run a single example
bin/console                                  # interactive prompt with gem loaded
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT. See [LICENSE.txt](LICENSE.txt).
