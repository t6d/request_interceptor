require "sinatra/base"

class RequestInterceptor::Application < Sinatra::Base
  def self.customize(&customizations)
    RequestInterceptor.define(self, &customizations)
  end

  def self.intercept(hostname, *args, &test)
    RequestInterceptor.run(hostname => self.new(*args), &test)
  end

  def self.hostname(hostname)
    define_singleton_method(:intercept) do |*args, &test|
      super(hostname, *args, &test)
    end
  end

  configure do
    disable :show_exceptions
    enable :raise_errors
  end
end
