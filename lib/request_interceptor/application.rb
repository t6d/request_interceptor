require "sinatra/base"

class RequestInterceptor::Application < Sinatra::Base
  configure do
    disable :show_exceptions
    enable :raise_errors
  end
end
