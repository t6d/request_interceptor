require "request_interceptor/version"

require "webmock"
require "uri"

class RequestInterceptor
  Transaction = Struct.new(:request, :response)

  class RequestWrapper < SimpleDelegator
    def path
      __getobj__.uri.path
    end

    def uri
      URI.parse(__getobj__.uri.to_s)
    end
  end

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

  def self.define(super_class = nil, &application_definition)
    Class.new(super_class || template, &application_definition)
  end

  def self.run(*args, &simulation)
    new(*args).run(&simulation)
  end

  attr_reader :applications
  attr_reader :transactions

  def initialize(applications)
    @applications = applications
    @transactions = []
  end

  def [](pattern)
    @applications[pattern]
  end

  def run(&simulation)
    transactions = []

    request_logging = ->(request, response) do
      next unless applications.any? { |pattern, _| request.uri.host.match(pattern) }
      transactions << Transaction.new(RequestWrapper.new(request), response)
    end

    SetupWebmock.perform(applications, request_logging, &simulation)

    transactions
  end
end

require_relative "request_interceptor/application"
require_relative "request_interceptor/setup_webmock"
