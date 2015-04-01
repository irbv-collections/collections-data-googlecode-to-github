# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'vascan_data_googlecode_to_github/version'

Gem::Specification.new do |spec|
  spec.name          = "vascan_data_googlecode_to_github"
  spec.version       = VascanDataGooglecodeToGithub::VERSION
  spec.authors       = ["Christian Gendreau"]
  spec.email         = ["christiangendreau@gmail.com"]
  spec.summary       = %q{VASCAN issues migration from GoogleCode to GitHub}
  spec.description   = %q{VASCAN issues migration from GoogleCode to GitHub}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"
  spec.add_dependency "json"
  spec.add_dependency "octokit"
  spec.add_dependency "thor"
end
