require "request_interceptor/version"

require "webmock"
require "uri"

class RequestInterceptor
  Transaction = Struct.new(:request, :response)

  WebMockSettings = Struct.new(:request_stubs, :callbacks, :net_connect_allowed, :show_body_diff, :show_stubbing_instructions) do
    alias net_connect_allowed? net_connect_allowed
  end

  class Request < SimpleDelegator
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
    @webmock_settings = WebMockSettings.new([], [])
  end

  def [](pattern)
    @applications[pattern]
  end

  def run(&simulation)
    clear_transaction_log
    setup_webmock

    simulation.call

    transactions
  ensure
    reset_webmock
  end

  protected

  attr_reader :webmock_settings

  private

  def clear_transaction_log
    @transactions = []
  end

  def setup_webmock
    webmock_settings.request_stubs = WebMock::StubRegistry.instance.request_stubs.dup || []
    webmock_settings.callbacks = WebMock::CallbackRegistry.callbacks.dup || []
    webmock_settings.net_connect_allowed = WebMock.net_connect_allowed?
    webmock_settings.show_body_diff = WebMock::Config.instance.show_body_diff
    webmock_settings.show_stubbing_instructions = WebMock::Config.instance.show_stubbing_instructions

    WebMock.after_request do |request, response|
      log_transaction(Request.new(request), response) if applications.any? { |pattern, _| request.uri.host.match(pattern) }
    end

    applications.each do |pattern, application|
      WebMock.stub_request(:any, pattern).to_rack(application)
    end

    WebMock.allow_net_connect!
    WebMock.hide_body_diff!
    WebMock.hide_stubbing_instructions!
    WebMock.enable!
  end

  def reset_webmock
    WebMock.disable_net_connect! unless webmock_settings.net_connect_allowed?
    WebMock::Config.instance.show_body_diff = webmock_settings.show_body_diff
    WebMock::Config.instance.show_stubbing_instructions = webmock_settings.show_stubbing_instructions
    WebMock::CallbackRegistry.reset
    webmock_settings.callbacks.each do |callback_settings|
      WebMock.after_request(callback_settings[:options], &callback_settings[:block])
    end
    WebMock::StubRegistry.instance.request_stubs = webmock_settings.request_stubs
  end

  def log_transaction(request, response)
    transactions << RequestInterceptor::Transaction.new(request, response)
  end
end

require "request_interceptor/application"
require "request_interceptor/status"
