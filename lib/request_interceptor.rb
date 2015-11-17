require "request_interceptor/version"

module RequestInterceptor
  class Transaction < Struct.new(:request, :reponse); end

  def self.template=(template)
    @template =
      case template
      when Proc
        Class.new(Application, &template)
      else
        template
      end
  end

  def self.template
    @template || Application
  end

  def self.define(hostname_pattern, &application_definition)
    application = Class.new(template, &application_definition)
    InterceptorDefinition.new(application, hostname_pattern)
  end

  def self.run(*applications, &simulation)
    Runner.new(*applications).run(&simulation)
  end
end

require "request_interceptor/application"
require "request_interceptor/interceptor_definition"
require "request_interceptor/runner"
require "request_interceptor/status"
