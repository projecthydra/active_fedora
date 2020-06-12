# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "active_fedora/version"

Gem::Specification.new do |s|
  s.name        = "active-fedora"
  s.version     = ActiveFedora::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Matt Zumwalt", "McClain Looney", "Justin Coyne"]
  s.email       = ["matt.zumwalt@yourmediashelf.com"]
  s.homepage    = %q{https://github.com/projecthydra/active_fedora}
  s.summary     = %q{A convenience libary for manipulating documents in the Fedora Repository.}
  s.description = %q{ActiveFedora provides for creating and managing objects in the Fedora Repository Architecture.}
  s.license = "APACHE2"
  s.required_ruby_version = '~> 2.0'

  s.add_dependency 'rsolr', '~> 1.0', '>= 1.0.10'
  s.add_dependency 'solrizer', '~> 3.4'
  s.add_dependency 'om', '~> 3.1'
  s.add_dependency 'nom-xml', '>= 0.5.1'
  s.add_dependency "activesupport", '>= 4.2.4', '< 6'
  s.add_dependency "activemodel", '>= 4.2', '< 6'
  s.add_dependency "active-triples", '~> 0.7.1'
  s.add_dependency "rdf-rdfxml", '~> 1.1'
  s.add_dependency "deprecation"
  s.add_dependency "ldp", '~> 0.5.0'

  s.add_development_dependency "rails"
  s.add_development_dependency "rdoc"
  s.add_development_dependency "yard"
  # Pin rake to 10.0 due to https://github.com/lsegal/yard/issues/947
  s.add_development_dependency "rake", '~> 10.0'
  s.add_development_dependency "solr_wrapper", "~> 0.4"
  s.add_development_dependency 'fcrepo_wrapper', '~> 0.2'
  s.add_development_dependency 'pry-byebug'
  s.add_development_dependency "rspec", "~> 3.0"
  s.add_development_dependency "rspec_junit_formatter"
  s.add_development_dependency "rspec-its"
  s.add_development_dependency "equivalent-xml"
  s.add_development_dependency "simplecov", '~> 0.8'
  # Pin to rubocop 0.38.0 due to https://github.com/nevir/rubocop-rspec/issues/78
  s.add_development_dependency "rubocop", '~> 0.38.0'
  s.add_development_dependency "rubocop-rspec", '~> 1.4'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {spec}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.extra_rdoc_files = [
    "LICENSE",
    "README.md"
  ]
  s.require_paths = ["lib"]

end
