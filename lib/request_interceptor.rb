require "request_interceptor/version"

require "net/http"
require "rack/mock"

class RequestInterceptor
  class Transaction < Struct.new(:request, :reponse); end

  GET = "GET".freeze
  POST = "POST".freeze
  PUT = "PUT".freeze
  DELETE = "DELETE".freeze

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
    @applications = {}
    @transactions = []

    applications.each { |pattern, application| self[pattern] = application }
  end

  def [](pattern)
    @applications[pattern]
  end

  def []=(pattern, application)
    @applications[pattern] = application
  end

  def run(&simulation)
    clear_transaction_log
    cache_original_net_http_methods
    override_net_http_methods
    simulation.call
    transactions
  ensure
    restore_net_http_methods
  end

  def request(http_context, request, body, &block)
    # use Net::HTTP set_body_internal to
    # keep the same behaviour as Net::HTTP
    request.set_body_internal(body)
    response = nil

    if mock_request = mock_request_for_application(http_context, request)
      mock_response = dispatch_mock_request(request, mock_request)

      # create response
      status = RequestInterceptor::Status.from_code(mock_response.status)
      response = status.response_class.new("1.1", status.value, status.description)

      # copy header to response
      mock_response.original_headers.each do |k, v|
        response.add_field(k, v)
      end

      # copy uri
      response.uri = request.uri

      # copy body to response
      response.body = mock_response.body

      # replace Net::HTTP::Response#read_body
      def response.read_body(_, &block)
        block.call(@body) unless block.nil?
        @body
      end

      # yield the response because Net::HTTP#request does
      block.call(response) unless block.nil?

      # log intercepted transaction
      log_transaction(request, response)
    else
      response = real_request(http_context, request, body, &block)
    end

    response
  end


  private

  def clear_transaction_log
    @transactions = []
  end

  def cache_original_net_http_methods
    @original_request_method = Net::HTTP.instance_method(:request)
    @original_start_method = Net::HTTP.instance_method(:start)
    @original_finish_method = Net::HTTP.instance_method(:finish)
  end

  def override_net_http_methods
    runner = self

    Net::HTTP.class_eval do
      def start
        @started = true
        return yield(self) if block_given?
        self
      end

      def finish
        @started = false
        nil
      end

      define_method(:request) do |request, body = nil, &block|
        runner.request(self, request, body, &block)
      end
    end
  end

  def restore_net_http_methods(instance = nil)
    if instance.nil?
      Net::HTTP.send(:define_method, :request, @original_request_method)
      Net::HTTP.send(:define_method, :start, @original_start_method)
      Net::HTTP.send(:define_method, :finish, @original_finish_method)
    else
      instance.define_singleton_method(:request, @original_request_method)
      instance.define_singleton_method(:start, @original_start_method)
      instance.define_singleton_method(:finish, @original_finish_method)
    end
  end

  def mock_request_for_application(http_context, request)
    _, application = applications.find { |pattern, _| pattern === http_context.address }
    Rack::MockRequest.new(application) if application
  end

  def dispatch_mock_request(request, mock_request)
    rack_env = request.to_hash

    case request.method
    when GET
      mock_request.get(request.path, rack_env)
    when POST
      mock_request.post(request.path, rack_env.merge(input: request.body))
    when PUT
      mock_request.put(request.path, rack_env.merge(input: request.body))
    when DELETE
      mock_request.delete(request.path, rack_env)
    else
      raise NotImplementedError, "Simulating #{request.method} is not supported"
    end
  end

  def real_request(http_context, request, body, &block)
    restore_net_http_methods(http_context)
    http_context.request(request, body, &block)
  end

  def log_transaction(request, response)
    transactions << RequestInterceptor::Transaction.new(request, response)
  end
end

require "request_interceptor/application"
require "request_interceptor/status"
