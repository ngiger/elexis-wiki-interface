# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'elexis/wiki/interface'

Gem::Specification.new do |spec|
  spec.name          = "elexis-wiki-interface"
  spec.version       = Elexis::Wiki::Interface::VERSION
  spec.authors       = ["Niklaus Giger"]
  spec.email         = ["niklaus.giger@member.fsf.org"]
  spec.summary       = "Interface between elexis source and wiki"
  spec.description   = "Support for pulling/pushing wiki content from source repository to elexis.wiki"
  spec.homepage      = "http://wiki.elexis.info"
  spec.license       = "GPLv3"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]
  spec.add_dependency 'rubyzip', '< 1.0.0'
  spec.add_dependency 'mediawiki-gateway'
  spec.add_dependency 'eclipse-plugin', '>= 0.1'
  spec.add_development_dependency "bundler", "~> 1.5"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "simplecov"
end
