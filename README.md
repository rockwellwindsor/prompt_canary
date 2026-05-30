# PromptCanary

Canary deployments for LLM prompts in Ruby. Declare prompts as versioned Ruby classes, route traffic by percentage or predicate, record telemetry, and automatically roll back misbehaving versions when error rate or latency exceeds a configured threshold.

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

This creates the `prompt_canary_calls` migration and mounts the engine in `config/routes.rb`. Then run:

```bash
rails db:migrate
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
    stable true
    model  "claude-opus-4-7"
    system "Extract structured data from this invoice."
  end
end
```

Exactly one version must be marked `stable`. Declaring zero or two stable versions raises at class load time.

Place prompt classes in `app/prompts/` — the Railtie loads them automatically on boot.

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
    stable true
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
  rollout percent: 0
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

If the predicate raises, the router falls back to the stable version — always safe.

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

When a rule fires, `PromptCanary.demote` is called automatically — the version's rollout is zeroed and a `prompt_canary.demoted` notification is emitted.

## Dashboard

The engine mounts a read-only web dashboard at the path configured in your routes (default `/prompt_canary`):

- **Index** — all registered prompt classes with per-version call counts, error rates, P95 latency, and last-called timestamps
- **Show** — version breakdown plus the 50 most recent calls with per-call latency, token counts, and error detail

No authentication is wired in by default. Protect the mount point with your app's existing auth if needed:

```ruby
authenticate :user, ->(u) { u.admin? } do
  mount PromptCanary::Engine, at: "/prompt_canary"
end
```

## Manual Rollback

From the command line:

```bash
prompt_canary demote InvoiceExtractor v2 --reason "error rate spike"
```

Or from Ruby:

```ruby
PromptCanary.demote(InvoiceExtractor, "v2", reason: "error rate spike")
```

## Notifications

Subscribe to demotion events:

```ruby
PromptCanary.subscribe("prompt_canary.demoted") do |payload|
  puts "#{payload[:prompt]} #{payload[:version]} demoted — #{payload[:reason]}"
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
