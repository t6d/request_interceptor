require "sinatra/base"

class RequestInterceptor::Application < Sinatra::Base
  class << self
    attr_accessor :hostname_pattern
  end
end
