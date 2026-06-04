#!/usr/bin/env ruby
# frozen_string_literal: true

# Run from the repo root: bundle exec ruby examples/demo.rb
#
# Uses a stubbed adapter by default so no API key is needed.
# To run against Anthropic, set ANTHROPIC_API_KEY and pass --real as an argument.

$LOAD_PATH.unshift File.join(__dir__, "../lib")
require "prompt_canary"

USE_REAL_API = ARGV.include?("--real")

# --- Configuration ---

PromptCanary.configure do |c|
  c.adapter = :anthropic
  c.storage = :memory
end

# --- Prompt definition ---

class InvoiceExtractor
  include PromptCanary::Promptable

  version "v1" do
    model  "claude-haiku-4-5-20251001"
    system "Extract structured data from this invoice. Return plain text."
  end

  version "v2" do
    model  "claude-haiku-4-5-20251001"
    system "Extract structured data from this invoice. Return JSON."
    rollout percent: 20
  end
end

# --- Adapter setup ---

if USE_REAL_API
  puts "Using real Anthropic API (ANTHROPIC_API_KEY must be set)\n\n"
  adapter = PromptCanary::Adapters::Anthropic.new
else
  puts "Using stubbed adapter (pass --real to hit Anthropic)\n\n"
  adapter = Object.new
  def adapter.call(version:, args:)
    {
      text: "Vendor: Acme Corp  Amount: $1,250.00  Date: 2026-01-15",
      latency_ms: rand(200..600),
      tokens: { input: 45, output: 18 },
      error: nil
    }
  end
end

# --- Demonstrate routing ---

puts "=== Routing demo (20% rollout to v2) ===\n\n"

results = 10.times.map do |i|
  result = InvoiceExtractor.call(
    user_message: "Invoice ##{i + 1}: Acme Corp, $1,250.00, 2026-01-15",
    context: { call_id: i },
    adapter: adapter
  )
  puts "call_id=#{i}  version=#{result.version_used}  latency=#{result.latency_ms}ms"
  result
end

v2_count = results.count { |r| r.version_used == "v2" }
puts "\n#{v2_count}/10 calls routed to v2 (expected ~2 at 20% rollout)\n\n"

# --- Show a full result ---

puts "=== Result structure ===\n\n"
r = results.first
puts "text:         #{r.text}"
puts "version_used: #{r.version_used}"
puts "model:        #{r.model}"
puts "latency_ms:   #{r.latency_ms}"
puts "tokens:       #{r.tokens.inspect}"
puts "error:        #{r.error.inspect}"
puts "recorded_at:  #{r.recorded_at}"
