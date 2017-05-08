require "request_interceptor/version"

require "webmock"
require "uri"

class RequestInterceptor
  Transaction = Struct.new(:request, :response)

  module RequestBackwardsCompatibility
    def path
      uri.request_uri
    end

    def uri
      URI.parse(super.to_s)
    end

    def method
      super.to_s.upcase
    end
  end

  class ApplicationWrapper < SimpleDelegator
    attr_reader :pattern

    def initialize(pattern, application)
      @pattern =
        case pattern
        when String
          %r{://#{Regexp.escape(pattern)}/}
        else
          pattern
        end

      super(application)
    end

    def intercepts?(uri)
      !!pattern.match(uri.normalize.to_s)
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

  def self.run(applications, &simulation)
    new(applications).run(&simulation)
  end

  attr_reader :applications
  attr_reader :transactions

  def initialize(applications)
    @applications = applications.map { |pattern, application| ApplicationWrapper.new(pattern, application) }
    @transactions = []
  end

  def run(&simulation)
    transactions = []

    request_logging = ->(request, response) do
      next unless applications.any? { |application| application.intercepts?(request.uri) }
      request.extend(RequestBackwardsCompatibility)
      transactions << Transaction.new(request, response)
    end

    WebMockManager.new(applications, request_logging).run_simulation(&simulation)

    transactions
  end
end

require_relative "request_interceptor/application"
require_relative "request_interceptor/webmock_manager"
require_relative "request_interceptor/webmock_patches"

WebMock.singleton_class.prepend(RequestInterceptor::WebMockPatches)
