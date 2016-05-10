require "sinatra/base"

class RequestInterceptor::Application < Sinatra::Base
  def self.customize(&customizations)
    RequestInterceptor.define(self, &customizations)
  end

  def self.intercept(host, *args, &test)
    RequestInterceptor.run(host => self.new(*args), &test)
  end

  def self.host(host)
    define_singleton_method(:intercept) do |*args, &test|
      super(host, *args, &test)
    end
  end

  configure do
    disable :show_exceptions
    enable :raise_errors
  end
end
