# frozen_string_literal: true

require "./lib/attr_keyring/version"

Gem::Specification.new do |spec|
  spec.name          = "attr_keyring"
  spec.version       = AttrKeyring::VERSION
  spec.authors       = ["Nando Vieira"]
  spec.email         = ["me@fnando.com"]

  spec.summary       = "Simple encryption-at-rest plugin for ActiveRecord."
  spec.description   = spec.summary
  spec.homepage      = "https://github.com/fnando/attr_keyring"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 3.3.0")

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`
      .split("\x0")
      .reject {|f| f.match(%r{^(test|spec|features)/}) }
  end

  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) {|f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "activerecord"
  spec.add_development_dependency "attr_vault"
  spec.add_development_dependency "bundler"
  spec.add_development_dependency "minitest-utils"
  spec.add_development_dependency "mocha"
  spec.add_development_dependency "pg"
  spec.add_development_dependency "pry-meta"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rubocop"
  spec.add_development_dependency "rubocop-fnando"
  spec.add_development_dependency "sequel"
  spec.add_development_dependency "simplecov"
end
