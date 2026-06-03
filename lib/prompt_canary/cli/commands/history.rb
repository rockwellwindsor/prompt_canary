# frozen_string_literal: true

module PromptCanary
  class CLI
    module Commands
      module History
        private

        def history(args)
          options = {}
          OptionParser.new do |opts|
            opts.on("--since PERIOD") { |p| options[:since] = p }
          end.parse!(args)

          prompt_name = args.first
          if prompt_name.nil?
            warn "Usage: prompt_canary history PROMPT_CLASS [--since Nd]"
            exit 1
          end

          require "prompt_canary/storage/active_record_adapter" unless defined?(PromptCanary::PromptEvent)
          history_scope(prompt_name, options[:since]).each { |e| puts format_event(e) }
        end

        def history_scope(prompt_name, since_period)
          scope = PromptCanary::PromptEvent.where(prompt: prompt_name).order(:recorded_at)
          return scope unless since_period

          scope.where("recorded_at >= ?", Time.now - (since_period.to_i * 24 * 60 * 60))
        end

        def format_event(event)
          parts = [event.recorded_at.strftime("%Y-%m-%d %H:%M"),
                   event.event.upcase.ljust(12),
                   event.version,
                   event_change(event),
                   "[#{event.triggered_by}]",
                   event_metric(event)].compact
          parts.join("  ").strip
        end

        def event_change(event)
          if event.previous_status || event.new_status
            "#{event.previous_status} → #{event.new_status}"
          elsif !event.previous_percent.nil? && !event.new_percent.nil?
            "#{event.previous_percent}% → #{event.new_percent}%"
          end
        end

        def event_metric(event)
          return unless event.triggering_metric

          "#{event.triggering_metric} #{event.triggering_value} > #{event.triggering_threshold}"
        end
      end
    end
  end
end
