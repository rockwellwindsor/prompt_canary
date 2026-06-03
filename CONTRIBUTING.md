# Contributing to PromptCanary

Bug reports and pull requests are welcome on GitHub. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](CODE_OF_CONDUCT.md).

## Getting started

```bash
git clone https://github.com/[USERNAME]/prompt_canary
cd prompt_canary
bin/setup
bundle exec rake   # runs tests + lint; everything should be green before you start
```

## Commit message format

This project uses a consistent commit message format. Copy and paste the template below for each commit — fill in the plain values, no labels:

```
FIX: Add router fallback for zero-percent rollout

(G)

Ensure the router returns the primary version when rollout percent is
explicitly set to 0, not just when omitted.
```

Fields in order:
1. **Subject** — `TYPE: Short summary of the change`. Type is one of: `FEATURE`, `FIX`, `DOCUMENTATION`, `STYLE`, `REFACTOR`, `CHORE`
2. **Status** — almost always `(G)`. Only commit when all tests are passing. `(R)` exists but should be used only in rare exceptional circumstances.
3. **Description** — fuller explanation of what changed and why

**We only commit green.** Run `bundle exec rake` before every commit and confirm the suite passes. A red commit should be the exception, not the norm.

## Development workflow

This project is built test-first. Before writing any production code, write a failing test that requires it. See [claude/PLAN.md](claude/PLAN.md) §4 for the full TDD methodology this project follows.

## Running tests

```bash
bundle exec rake spec                              # full suite
bundle exec rspec spec/path/to/foo_spec.rb        # single file
bundle exec rspec spec/path/to/foo_spec.rb:42     # single example
bundle exec rubocop                               # lint
```
