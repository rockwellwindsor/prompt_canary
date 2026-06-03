#!/usr/bin/env ruby
# frozen_string_literal: true

# Run from the repo root: bundle exec ruby examples/auto_rollback.rb
#
# Demonstrates automatic rollback: seeds synthetic errors into storage,
# runs the monitor, and shows the version being demoted.

$LOAD_PATH.unshift File.join(__dir__, "../lib")
require "prompt_canary"

# --- Configuration ---

PromptCanary.configure do |c|
  c.adapter = :anthropic
  c.storage = :memory
end

# --- Prompt definition ---

class SupportResponder < PromptCanary::Prompt
  version "v1" do
    model  "claude-haiku-4-5-20251001"
    system "You are a helpful customer support agent."
  end

  version "v2" do
    model  "claude-haiku-4-5-20251001"
    system "You are a concise customer support agent. Keep replies under 50 words."
    rollout percent: 30
    rollback_if :error_rate,  greater_than: 0.05, over: 100
    rollback_if :latency_p95, greater_than: 2000, over: 100
  end
end

storage  = PromptCanary::Storage::Memory.new
recorder = PromptCanary::Recorder.new(storage: storage)

# --- Subscribe to demotion events ---

PromptCanary.subscribe("prompt_canary.demoted") do |payload|
  puts "  [notification] #{payload[:prompt]} #{payload[:version]} demoted — #{payload[:reason]}"
end

# --- Seed healthy traffic ---

puts "=== Seeding 100 calls for v2 (2% error rate — below threshold) ===\n\n"

100.times do |i|
  storage.write(
    prompt: "SupportResponder",
    version: "v2",
    latency_ms: rand(200..800),
    tokens: { input: 20, output: 15 },
    error: i < 2 ? StandardError.new("timeout") : nil,
    recorded_at: Time.now
  )
end

puts "Running monitor..."
PromptCanary::Monitor.new(recorder: recorder).evaluate(SupportResponder)

v2 = SupportResponder.versions.find { |v| v.name == "v2" }
puts "v2 rollout percent: #{v2.rollout[:percent]}% (no change expected)\n\n"

# --- Seed failing traffic ---

puts "=== Seeding 100 more calls (12% error rate — above threshold) ===\n\n"

100.times do |i|
  storage.write(
    prompt: "SupportResponder",
    version: "v2",
    latency_ms: rand(200..800),
    tokens: { input: 20, output: 15 },
    error: i < 12 ? StandardError.new("model overloaded") : nil,
    recorded_at: Time.now
  )
end

puts "Running monitor..."
PromptCanary::Monitor.new(recorder: recorder).evaluate(SupportResponder)

puts "v2 rollout percent: #{v2.rollout[:percent]}% (expected 0 — demoted)\n\n"

# --- Confirm router falls back to primary ---

puts "=== Router now falls back to v1 (primary) ===\n\n"

adapter = Object.new
def adapter.call(version:, args:)
  { text: "Happy to help!", latency_ms: 250, tokens: { input: 10, output: 5 }, error: nil }
end

5.times do |i|
  result = SupportResponder.call(
    user_message: "Where is my order?",
    context: { call_id: i },
    adapter: adapter,
    recorder: recorder
  )
  puts "call_id=#{i}  version=#{result.version_used}"
end
