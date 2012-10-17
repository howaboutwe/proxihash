# -*- encoding: utf-8 -*-
$:.unshift File.expand_path('lib', File.dirname(__FILE__))
require 'proxihash/version'

Gem::Specification.new do |gem|
  gem.name          = 'proxihash'
  gem.version       = Proxihash::VERSION
  gem.authors       = ['George Ogata']
  gem.email         = ['george.ogata@gmail.com']
  gem.summary       = "Hashes for geospatial proximity searches."
  gem.homepage      = 'http://github.com/howaboutwe/proxisearch'

  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")

  gem.add_development_dependency 'ritual', '~> 0.4.1'
end
