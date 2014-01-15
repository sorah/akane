# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'akane/version'

Gem::Specification.new do |spec|
  spec.name          = "akane"
  spec.version       = Akane::VERSION
  spec.authors       = ["Shota Fukumori (sora_h)"]
  spec.email         = ["her@sorah.jp"]
  spec.description   = %q{Log the timeline}
  spec.summary       = %q{Log your timeline to something}
  spec.homepage      = "https://github.com/sorah/akane"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "elasticsearch", "~> 0.4.1"
  spec.add_dependency "twitter", "~> 5.5.1"
  spec.add_dependency "oauth", ">= 0.4.7"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec", "~> 2.14.1"
  spec.add_development_dependency "simplecov"
end
