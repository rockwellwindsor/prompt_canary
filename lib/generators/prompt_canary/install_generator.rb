# frozen_string_literal: true

require "rails/generators"
require "rails/generators/migration"

module PromptCanary
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      def self.next_migration_number(_path)
        Time.now.utc.strftime("%Y%m%d%H%M%S")
      end

      def create_migration
        migration_template(
          "create_prompt_canary_calls.rb",
          "db/migrate/create_prompt_canary_calls.rb"
        )
      end

      def show_instructions
        say "\nPromptCanary installed!", :green
        say "  1. Run: rails db:migrate"
        say "  2. Set storage: :active_record in your PromptCanary initializer"
        say "  3. Add to config/recurring.yml:"
        say "       prompt_canary_monitor:"
        say "         class: PromptCanary::MonitorJob"
        say "         schedule: every 5 minutes\n"
      end
    end
  end
end
