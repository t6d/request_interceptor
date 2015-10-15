require "delegate"
require "net/http"

require "rack"

class RequestInterceptor::Runner
  class SocketSimulator < SimpleDelegator
    def read_all(*)
      __getobj__.read
    end
  end

  GET = "GET".freeze

  attr_reader :applications

  def initialize(*applications)
    @applications = applications
  end

  def run(&simulation)
    runner = self

    original_request_method = Net::HTTP.instance_method(:request)
    original_start_method = Net::HTTP.instance_method(:start)
    original_finish_method = Net::HTTP.instance_method(:finish)

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

    simulation.call
  ensure
    Net::HTTP.send(:define_method, :request, original_request_method)
    Net::HTTP.send(:define_method, :start, original_start_method)
    Net::HTTP.send(:define_method, :finish, original_finish_method)
  end

  def request(request, body, &block)
    application = applications.find { |app| app.hostname_pattern === request["Host"] }
    mock_request = Rack::MockRequest.new(application)

    mock_response =
      case request.method
      when GET
        mock_request.get(request.path)
      else
        raise NotImplementedError, "Simulating #{request.method} is not supported"
      end

    status = RequestInterceptor::Status.from_code(mock_response.status)
    response = status.response_class.new("1.1", status.value, status.description)
    mock_response.original_headers.each { |k, v| response.add_field(k, v) }
    response.body = mock_response.body

    block.call(response) if block
    response
  end
end
