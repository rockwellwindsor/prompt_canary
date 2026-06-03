# frozen_string_literal: true

module PromptCanary
  class CLI
    module Commands
      module Status
        private

        def status(args)
          prompt_name = args.first
          if prompt_name.nil?
            warn "Usage: prompt_canary status PROMPT_CLASS"
            exit 1
          end

          prompt_class = begin
            Object.const_get(prompt_name)
          rescue NameError
            warn "Unknown prompt class: #{prompt_name}"
            exit 1
          end

          primary_name = prompt_class.primary_version.name
          puts "#{prompt_name}:"
          prompt_class.versions.each do |v|
            label = version_status(prompt_class.name, v.name, primary_name)
            percent = v.rollout.fetch(:percent, 0)
            traffic = percent.positive? ? "#{percent}% traffic (canary)" : "no canary traffic"
            puts "  #{v.name.ljust(6)}  #{label.ljust(12)}  #{traffic}"
          end
        end

        def version_status(prompt_name, version_name, primary_name)
          if demoted_in_db?(prompt_name, version_name)
            "DEMOTED"
          elsif version_name == primary_name
            "PRIMARY"
          else
            "CANDIDATE"
          end
        end

        def demoted_in_db?(prompt_name, version_name)
          return false unless defined?(PromptCanary::RolloutOverride)

          PromptCanary::RolloutOverride
            .where(prompt: prompt_name, version: version_name, rollout_override: 0)
            .exists?
        rescue ::ActiveRecord::ConnectionNotEstablished, ::ActiveRecord::StatementInvalid
          false
        end
      end
    end
  end
end
