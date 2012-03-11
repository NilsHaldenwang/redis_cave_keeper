# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "redis_cave_keeper/version"

Gem::Specification.new do |s|
  s.name        = "redis_cave_keeper"
  s.version     = RedisCaveKeeper::VERSION
  s.authors     = ["Nils Haldenwang"]
  s.email       = ["n.haldenwang@googlemail.com"]
  s.homepage    = "https://github.com/NilsHaldenwang/redis_cave_keeper"
  s.summary     = %q{Implementation of pessimistic locking for redis.}
  s.description = %q{Implementation of pessimistic locking for redis.}

  s.rubyforge_project = "redis_cave_keeper"

  s.extra_rdoc_files = ["README.md"]

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_development_dependency "rake", "~> 0.9.2"
  s.add_development_dependency "rspec", "~> 2.8.0"
  s.add_development_dependency "watchr", "~> 0.7"
  s.add_development_dependency "redis", "~> 2.2.2"
end
