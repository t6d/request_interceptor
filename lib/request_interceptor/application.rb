require "sinatra/base"

class RequestInterceptor::Application < Sinatra::Base
  class << self
    def customize(&customizations)
      RequestInterceptor.define(self, &customizations)
    end

    def intercept(pattern, *args, &test)
      RequestInterceptor.run(pattern => self.new(*args), &test)
    end

    def match(pattern)
      define_singleton_method(:intercept) do |*args, &test|
        super(pattern, *args, &test)
      end
    end

    alias host match
  end

  configure do
    disable :show_exceptions
    enable :raise_errors
  end
end
