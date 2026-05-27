# frozen_string_literal: true

require "optparse"

module PromptCanary
  class CLI
    def run(args)
      subcommand = args.shift
      case subcommand
      when "demote" then demote(args)
      else
        warn "Unknown command: #{subcommand}"
        exit 1
      end
    end

    private

    def demote(args)
      options = {}
      OptionParser.new do |opts|
        opts.on("--reason REASON") { |r| options[:reason] = r }
      end.parse!(args)

      prompt_name, version_name = args
      prompt_class = Object.const_get(prompt_name)
      PromptCanary.demote(prompt_class, version_name, reason: options[:reason])
    end
  end
end
