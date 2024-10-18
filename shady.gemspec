# encoding: utf-8

Gem::Specification.new do |gem|
  gem.name        = "shady"
  gem.version     = `grep -m 1 '^\s*@version' bin/shady | head -1 | cut -f 2 -d '"'`
  gem.author      = "Steve Shreeve"
  gem.email       = "steve.shreeve@gmail.com"
  gem.summary     = "This gem allows easy conversion between Slim, XML, and hashes"
  gem.description = "Ruby gem to work with Slim, XML, and hashes"
  gem.homepage    = "https://github.com/shreeve/shady"
  gem.license     = "MIT"
  gem.platform    = Gem::Platform::RUBY
  gem.files       = `git ls-files`.split("\n") - %w[.gitignore]
  gem.executables = `cd bin && git ls-files .`.split("\n")
  gem.required_ruby_version = Gem::Requirement.new(">= 3.0") if gem.respond_to? :required_ruby_version=

  gem.add_dependency "bindings", "~>1.0.0"
  gem.add_dependency "nokogiri", "~>1.16.7"
  gem.add_dependency "slim"    , "~>5.2.1"
end
