## [Unreleased]

## [0.3.0] - 2026-06-03

### Added

- `PromptCanary.promote` — marks a version as primary at runtime; the previous primary becomes a candidate. Writes `PrimaryOverride` to DB so the designation survives restarts. Does not change traffic percentages.
- `PromptCanary.set_canary` — adjusts a version's canary traffic percentage at runtime without a deploy. Independent of status. Raises `ArgumentError` if percent is zero — use `demote` to stop traffic.
- `PromptCanary::PromptEvent` AR model — persists a full audit trail to `prompt_canary_events` with event type, previous/new status, previous/new percent, reason, triggered-by, and monitor metric fields.
- All deployment operations (`promote`, `demote`, `restore`, `set_canary`) write audit events to `prompt_canary_events`.
- `promote` writes two events: one for the promoted version and a `superseded` event for the displaced primary.
- Monitor passes `triggered_by: "monitor"` and metric metadata (`triggering_metric`, `triggering_value`, `triggering_threshold`) through `demote` so auto-rollbacks are distinguishable from manual ones in the audit trail.
- `CannotDemotePrimaryError` — raised when attempting to demote the primary version with no other viable candidate, preventing the system from being left without a route target.
- `DemotedVersionError` — raised when `set_canary` targets a demoted version. Call `restore` first.
- `Version#demoted?` — tracks demoted state in memory for non-AR storage paths.
- `Deployment` module — extracted from `PromptCanary` to group the four runtime operations (`promote`, `demote`, `restore`, `set_canary`) with a clear SRP boundary.
- CLI `promote` subcommand — `prompt_canary promote PromptClass version [--reason "..."]`
- CLI `history` subcommand — `prompt_canary history PromptClass [--since 7d]`; validates period format.
- CLI `status` subcommand — `prompt_canary status PromptClass`; shows current status and traffic for each version.
- Dashboard Promote button — appears on the show page for candidate versions; absent for primary and demoted versions.
- Dashboard deployment history — show page surfaces the last 10 `PromptEvent` rows so operators can see what happened to a prompt without leaving the dashboard.
- Generator now creates all four tables in a single migration: `prompt_canary_calls`, `prompt_canary_rollout_overrides`, `prompt_canary_primary_overrides`, `prompt_canary_events`.

### Changed

- `demote` is now idempotent via `find_or_initialize_by` — demoting an already-demoted version does not error or create duplicate rows.
- `restore` restores the pre-demotion traffic percentage (stored at demotion time) rather than defaulting to zero.
- Router reads `PrimaryOverride` before falling back to first-declared default — DB-promoted versions survive restarts.
- `--since` validation in `history` command — invalid formats (e.g. `abc`, `0d`) exit with a clear error instead of silently querying all records.

### Breaking Changes

| Change | Migration |
|---|---|
| `stable: true` removed from version DSL | Delete `stable: true` from all version declarations. The first declared version is primary automatically. |
| `set_canary(prompt, version, 0)` raises `ArgumentError` | Use `PromptCanary.demote` to stop traffic to a version. |

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
