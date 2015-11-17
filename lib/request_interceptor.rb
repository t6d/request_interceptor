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

  def self.define(&application_definition)
    Class.new(template, &application_definition)
  end

  def self.new(*args)
    Runner.new(*args)
  end

  def self.run(*args, &simulation)
    new(*args).run(&simulation)
  end
end

require "request_interceptor/application"
require "request_interceptor/runner"
require "request_interceptor/status"
