require "sinatra/base"

class RequestInterceptor::Application < Sinatra::Base
  def self.customize(&customizations)
    RequestInterceptor.define(self, &customizations)
  end

  def self.intercept(hostname, **options, &test)
    app = options.empty? ? self : self.new(**options)
    RequestInterceptor.run(hostname => app, &test)
  end

  def self.hostname(default_hostname)
    define_singleton_method(:intercept) do |hostname = nil, **options, &test|
      super(hostname || default_hostname, **options, &test)
    end
  end

  configure do
    disable :show_exceptions
    enable :raise_errors
  end
end
