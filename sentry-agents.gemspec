# frozen_string_literal: true

require_relative "lib/sentry/agents/version"

Gem::Specification.new do |spec|
  spec.name = "sentry-agents"
  spec.version = Sentry::Agents::VERSION
  spec.authors = ["Istvan Hoka"]
  spec.email = ["istvan.hoka@gmail.com"]

  spec.summary = "Sentry Gen AI instrumentation for AI/LLM agents in Ruby"
  spec.description = <<~DESC
    Provides Sentry Gen AI instrumentation for AI/LLM agents,
    supporting multiple providers (Anthropic, OpenAI, etc.)
    with auto-instrumentation for RubyLLM and LangChain.rb.
  DESC
  spec.homepage = "https://github.com/ihoka/sentry-agents-ruby"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.glob("lib/**/*") + %w[README.md LICENSE CHANGELOG.md]
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "sentry-ruby", ">= 5.0.0"

  # Development dependencies
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rubocop", "~> 1.21"
  spec.add_development_dependency "rubocop-minitest", "~> 0.35"
end
