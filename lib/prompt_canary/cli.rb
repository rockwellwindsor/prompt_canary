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
      if prompt_name.nil? || version_name.nil?
        warn "Usage: prompt_canary demote PROMPT_CLASS VERSION [--reason REASON]"
        exit 1
      end

      prompt_class = begin
        Object.const_get(prompt_name)
      rescue NameError
        warn "Unknown prompt class: #{prompt_name}"
        exit 1
      end
      PromptCanary.demote(prompt_class, version_name, reason: options[:reason])
    end
  end
end
