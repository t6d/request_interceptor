# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'request_interceptor/version'

Gem::Specification.new do |spec|
  spec.name          = "request_interceptor"
  spec.version       = RequestInterceptor::VERSION
  spec.authors       = ["Konstantin Tennhard", "Kevin Hughes"]
  spec.email         = ["me@t6d.de", "kevinhughes27@gmail.com"]

  spec.summary       = %q{Sinatra based foreign API simulation}
  spec.homepage      = "http://github.com/t6d/request_interceptor"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "sinatra"
  spec.add_runtime_dependency "rack"

  spec.add_development_dependency "bundler", "~> 1.9"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "pry"
end
