require "sinatra/base"

class RequestInterceptor::Application < Sinatra::Base
  class << self
    attr_accessor :hostname_pattern
  end

  configure do
    disable :show_exceptions
    enable :raise_errors
  end
end
