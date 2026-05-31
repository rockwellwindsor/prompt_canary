## [Unreleased]

## [0.2.0] - 2026-05-30

### Added

- `PromptCanary::Promptable` module — compose prompt behavior via `include` without consuming the host class's superclass slot
- `PromptCanary::AdapterFactory` and `StorageFactory` — registry pattern replacing case statements; raises `ConfigurationError` immediately for unknown values
- `PromptCanary::PromptExecutor` — extracts router → adapter → recorder → result orchestration out of `Promptable#call`
- `Configuration#validate!` — centralizes configuration validation; called at end of `configure` block
- Dynamic system prompts — `system` DSL field accepts a block receiving call-time args, enabling runtime data in prompt text
- `RollbackRule` value object — replaces plain hashes; owns comparison logic via `violated_by?`
- `Recorder#stats` — returns `{ call_count:, error_rate:, latency_p95:, last_called_at: }` over a configurable window
- `PromptCanary.stats` — convenience method for Rails console access; no setup required
- `PromptCanary.register_prompt` / `registered_prompts` — prompt class registry populated automatically when `Promptable` is included
- `PromptCanary::Railtie` — loads prompt classes from `app/prompts/` at boot; warns when `:sqlite` is configured in a Rails context
- `PromptCanary::MonitorJob` — `ActiveJob::Base` subclass that iterates registered prompts and runs the monitor; host app only schedules it
- `Storage::ActiveRecord` — AR-backed storage using the host app's existing database connection and migration system
- `PromptCanary::RolloutOverride` — AR model persisting demotions to `prompt_canary_rollout_overrides`; survives restarts and redeploys
- `PromptCanary.restore` — clears a demotion override and emits `prompt_canary.restored`; router immediately resumes class-defined rollout
- `rails generate prompt_canary:install` — creates both `prompt_canary_calls` and `prompt_canary_rollout_overrides` migrations and mounts the engine
- `PromptCanary::Engine` — mountable Rails engine with read-only dashboard; index and show views display per-version stats, active/inactive row styling, and demoted badge
- Router reads `prompt_canary_rollout_overrides` on every request when AR is available — demoted versions receive zero traffic without a redeploy
- Dashboard active/inactive styling — inactive versions (zero rollout or demoted) rendered at reduced opacity; order is stable so a status change is visible without reordering

### Changed

- `PromptCanary::Prompt` is deprecated — `include PromptCanary::Promptable` is the correct pattern; `Prompt` emits a deprecation warning from `inherited`
- `PromptCanary.demote` writes a `RolloutOverride` record when using AR storage instead of mutating in-memory version state — class-defined rollout is preserved so restore requires no knowledge of the original value
- Adapter gems (`anthropic`, etc.) are the caller's dependency — not declared in gemspec to avoid forcing unused adapters on callers using custom implementations

### Fixed

- `frozen_string_literal` consistency across all files

## [0.1.0] - 2026-05-27

### Added

- `Prompt` DSL — declare versioned LLM prompts as Ruby classes with `version`, `stable`, `model`, `system`, `rollout`, `rollout_to`, and `rollback_if`
- `Router` — deterministic CRC32-based percentage routing and predicate routing; falls back to stable on missing `call_id` or predicate exception
- `Adapters::Anthropic` — Anthropic SDK v1.43.0 adapter; captures latency, token usage, and errors in a uniform telemetry hash
- `Recorder` — writes call telemetry to storage; computes `error_rate` and `latency_p95` (nearest-rank) over configurable request windows
- `Storage::Memory` — in-process storage for tests and development
- `Storage::SQLite` — persistent SQLite storage for production use
- `Monitor` — evaluates `rollback_if` rules against recorded metrics; calls `PromptCanary.demote` when a rule fires
- `PromptCanary.demote` — zeros a version's rollout percent and emits a `prompt_canary.demoted` notification
- `PromptCanary.subscribe` — simple pub/sub for demotion notifications; no ActiveSupport dependency
- `Result` — immutable value object returned by `Prompt.call`: `text`, `version_used`, `model`, `latency_ms`, `tokens`, `error`, `recorded_at`
- `CLI` — `prompt_canary demote PromptClass version --reason "..."` for manual rollbacks from scripts and cron jobs
- Configuration validation at `configure` time — raises `ConfigurationError` immediately if `adapter` or `storage` is not set
