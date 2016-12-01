# -*- encoding: utf-8 -*-
require File.expand_path('../lib/mongo_adaptor/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Jon Rowe"]
  gem.email         = ["hello@jonrowe.co.uk"]
  gem.description   = %q{A simple mongo handler. Translates Structs into Mongo and back.}
  gem.summary       = %q{A simple mongo handler. Translates Structs into Mongo and back.}
  gem.homepage      = "https://github.com/JonRowe/MongoAdaptor"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "mongo_adaptor"
  gem.require_paths = ["lib"]
  gem.version       = MongoAdaptor::VERSION
  gem.required_ruby_version = '>= 1.9.3'

  gem.add_dependency 'mongo', '~> 2.4'
  gem.add_dependency 'mongo-configure', '~> 2.0.0'

  if RUBY_VERSION > '1.9.2'
    gem.add_development_dependency 'rake'
  else
    gem.add_development_dependency 'rake', '< 11'
  end
  gem.add_development_dependency 'rspec'
end
