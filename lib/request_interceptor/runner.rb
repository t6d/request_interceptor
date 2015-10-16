require "delegate"
require "net/http"

require "rack/mock"

class RequestInterceptor::Runner
  GET = "GET".freeze
  POST = "POST".freeze
  PUT = "PUT".freeze
  DELETE = "DELETE".freeze

  attr_reader :applications
  attr_reader :transactions

  def initialize(*applications)
    @applications = applications
    @transactions = []
  end

  def run(&simulation)
    cache_original_nethttp_methods
    override_nethttp_methods
    simulation.call
    transactions
  ensure
    restore_nethttp_methods
  end

  def request(request, body, &block)
    # use Net::HTTP set_body_internal to
    # keep the same behaviour as Net::HTTP
    request.set_body_internal(body)
    response = nil

    if mock_request = mock_request_for_application(request)
      mock_response = dispatch_mock_request(request, mock_request)

      # create response
      status = RequestInterceptor::Status.from_code(mock_response.status)
      response = status.response_class.new("1.1", status.value, status.description)

      # copy header to response
      mock_response.original_headers.each do |k, v|
        response.add_field(k, v)
      end

      # copy body to response
      response.body = mock_response.body

      # Net::HTTP#request yields the response
      block.call(net_http_response) if block
    else
      response = real_request(request)
    end

    log_transaction(request, response)

    response
  end

  private

  def cache_original_nethttp_methods
    @original_request_method = Net::HTTP.instance_method(:request)
    @original_start_method = Net::HTTP.instance_method(:start)
    @original_finish_method = Net::HTTP.instance_method(:finish)
  end

  def override_nethttp_methods
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
        runner.request(request, body, &block)
      end
    end
  end

  def restore_nethttp_methods
    Net::HTTP.send(:define_method, :request, @original_request_method)
    Net::HTTP.send(:define_method, :start, @original_start_method)
    Net::HTTP.send(:define_method, :finish, @original_finish_method)
  end

  def mock_request_for_application(request)
    application = applications.find { |app| app.hostname_pattern === request["Host"] }
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

  def real_request(request)
    restore_nethttp_methods

    uri = request.uri
    http = Net::HTTP.new(uri.host, uri.port)
    http.request(request)
  end

  def log_transaction(request, response)
    transactions << RequestInterceptor::Transaction.new(request, response)
  end
end
