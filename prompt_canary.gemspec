# frozen_string_literal: true

require_relative "lib/prompt_canary/version"

Gem::Specification.new do |spec|
  spec.name = "prompt_canary"
  spec.version = PromptCanary::VERSION
  spec.authors = ["Rockwell Windsor Rice"]
  spec.email = ["rockwellwindsor@gmail.com"]

  spec.summary = "Canary deploys and automatic rollback for LLM prompts in Ruby."
  spec.description = "Declare prompts as Ruby classes with versioned configurations, route traffic " \
                     "by percentage or predicate, record telemetry, and automatically roll back " \
                     "misbehaving versions."
  spec.homepage = "https://github.com/rockwellwindsor/prompt_canary"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/rockwellwindsor/prompt_canary"
  spec.metadata["changelog_uri"] = "https://github.com/rockwellwindsor/prompt_canary/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .github/ .rubocop.yml claude/]) ||
          f.end_with?(".db")
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
