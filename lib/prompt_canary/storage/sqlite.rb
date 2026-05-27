# frozen_string_literal: true

require "sqlite3"
require "json"

module PromptCanary
  module Storage
    class SQLite
      def initialize(path: "prompt_canary.db")
        @db = ::SQLite3::Database.new(path)
        @db.results_as_hash = true
        create_table
      end

      def write(record)
        @db.execute(
          "INSERT INTO calls (prompt, version, latency_ms, tokens, error, recorded_at) VALUES (?, ?, ?, ?, ?, ?)",
          [
            record[:prompt],
            record[:version],
            record[:latency_ms],
            JSON.dump(record[:tokens]),
            record[:error]&.message,
            record[:recorded_at].iso8601
          ]
        )
      end

      def read_recent(prompt:, version:, limit:)
        rows = @db.execute(
          "SELECT * FROM calls WHERE prompt = ? AND version = ? ORDER BY recorded_at DESC LIMIT ?",
          [prompt, version, limit]
        )

        rows.reverse.map do |row|
          {
            prompt: row["prompt"],
            version: row["version"],
            latency_ms: row["latency_ms"],
            tokens: row["tokens"] ? JSON.parse(row["tokens"], symbolize_names: true) : nil,
            error: row["error"] ? StandardError.new(row["error"]) : nil,
            recorded_at: Time.parse(row["recorded_at"])
          }
        end
      end

      private

      def create_table
        @db.execute(<<~SQL)
          CREATE TABLE IF NOT EXISTS calls (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            prompt      TEXT    NOT NULL,
            version     TEXT    NOT NULL,
            latency_ms  INTEGER,
            tokens      TEXT,
            error       TEXT,
            recorded_at TEXT    NOT NULL
          )
        SQL
      end
    end
  end
end
