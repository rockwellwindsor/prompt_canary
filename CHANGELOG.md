## [Unreleased]

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
