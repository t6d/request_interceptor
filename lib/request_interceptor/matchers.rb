module RequestInterceptor::Matchers
  class MatcherWrapper < SimpleDelegator
    def ===(object)
      matches?(object)
    end

    def to_s
      description
    end
  end

  class InterceptedRequest
    attr_reader :method
    attr_reader :path
    attr_reader :query
    attr_reader :body
    attr_reader :transactions

    def initialize(method, path)
      @method = method
      @path = path
      @count = (1..Float::INFINITY)
      @transactions = []
    end

    ##
    # Chains
    ##

    def count(count = nil)
      return @count if count.nil?

      @count =
        case count
        when Integer
          (count .. count)
        when Range
          count
        else
          raise ArgumentError
        end

      self
    end

    def with_query(query)
      query_matcher =
        if query.respond_to?(:matches?) && query.respond_to?(:failure_message)
          query
        else
          RSpec::Matchers::BuiltIn::Eq.new(query)
        end

      @query = MatcherWrapper.new(query_matcher)

      self
    end

    def with_body(body)
      body_matcher =
        if body.respond_to?(:matches?) && body.respond_to?(:failure_message)
          body
        else
          RSpec::Matchers::BuiltIn::Eq.new(body)
        end

      @body = MatcherWrapper.new(body_matcher)

      self
    end

    ##
    # Rspec Matcher Protocol
    ##

    def matches?(transactions)
      @transactions = transactions
      count.cover?(matching_transactions.count)
    end

    def failure_message
      expected_request = "#{format_method(method)} #{path}"
      expected_request += " with query #{format_object(query)}" if query
      expected_request += " and" if query && body
      expected_request += " with body #{format_object(body)}" if body

      similar_intercepted_requests = similar_transactions.map.with_index do |transaction, index|
        method = format_method(transaction.request.method)
        path = transaction.request.path
        query = transaction.request.query
        body = transaction.request.body
        indentation_required = index != 0

        message = "#{method} #{path}"
        message += (query.nil? || query.empty?) ? " with no query" : " with query #{format_object(query)}"
        message += (body.nil? || body.empty?) ? " and with no body" : " and with body #{format_object(body)}"
        message = " " * 10 + message if indentation_required
        message
      end

      similar_intercepted_requests = ["none"] if similar_intercepted_requests.none?

      "\nexpected: #{expected_request}" \
        "\n     got: #{similar_intercepted_requests.join("\n")}"
    end

    def failure_message_when_negated
      message = "intercepted a #{format_method(method)} request to #{path}"
      message += " with query #{format_object(query)}" if query
      message += " and" if query && body
      message += " with body #{format_object(body)}" if body
      message
    end

    def description
      "should intercept a #{format_method(method)} request to #{path}"
    end

    ##
    # Helper methods
    ##

    private

    def format_method(method)
      method.to_s.upcase
    end

    def format_object(object)
      RSpec::Support::ObjectFormatter.format(object)
    end

    def matching_transactions
      transactions.select do |transaction|
        request = transaction.request
        request.method?(method) &&
          request.path?(path) &&
          request.query?(query) &&
          request.body?(body)
      end
    end

    def similar_transactions
      transactions.select do |transaction|
        request = transaction.request
        request.method?(method) && request.path?(path)
      end
    end
  end

  def have_intercepted_request(*args)
    InterceptedRequest.new(*args)
  end
  alias contain_intercepted_request have_intercepted_request
end

RSpec.configure do |config|
  config.include(RequestInterceptor::Matchers)
end
