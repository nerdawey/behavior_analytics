# frozen_string_literal: true

require_relative "lib/behavior_analytics/version"

Gem::Specification.new do |spec|
  spec.name = "behavior_analytics"
  spec.version = BehaviorAnalytics::VERSION
  spec.authors = ["nerdawey"]
  spec.email = ["nerdawy@icloud.com"]

  spec.summary = "Track user behavior events with flexible context filtering and comprehensive analytics"
  spec.description = "A Ruby gem for tracking user behavior events with multi-tenant support, " \
                     "computing analytics (engagement scores, time-based trends, feature usage), " \
                     "and supporting API calls, feature usage, and custom events."
  spec.homepage = "https://github.com/nerdawey/behavior_analytics"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .circleci appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "activesupport", ">= 6.0"

  # Development dependencies
  spec.add_development_dependency "activerecord", ">= 6.0"
  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "sqlite3", "~> 1.6"
end
