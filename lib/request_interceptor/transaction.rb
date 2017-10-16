class RequestInterceptor::Transaction
  class HTTPMessage
    include SmartProperties
    property :body

    def initialize(*args, headers: {}, **kwargs)
      @headers = headers.dup
      super(*args, **kwargs)
    end

    def [](name)
      @headers[name]
    end

    def []=(name, value)
      @headers[name] = value
    end

    def headers
      @headers.dup
    end
  end

  class Request < HTTPMessage
    property :method, converts: ->(method) { method.to_s.upcase.freeze }, required: true
    property :uri, accepts: URI, converts: ->(uri) { URI(uri.to_s) }, required: true
    property :body

    def method?(method)
      normalized_method = method.to_s.upcase
      normalized_method == self.method
    end

    def path?(path)
      path === self.path
    end

    def path
      uri.path
    end

    def request_uri?(request_uri)
      request_uri === self.request_uri
    end

    def request_uri
      uri.request_uri
    end

    def query
      Rack::Utils.parse_nested_query(uri.query).deep_symbolize_keys!
    end

    def query?(query_matcher)
      return true if query_matcher.nil?
      query_matcher === self.query
    end

    def body?(body_matcher)
      return true if body_matcher.nil?

      body = case self["Content-Type"]
      when "application/json"
        ActiveSupport::JSON.decode(self.body).deep_symbolize_keys!
      else
        self.body
      end

      body_matcher === body
    end
  end

  class Response < HTTPMessage
    property :status_code, required: true
    property :body
  end

  include SmartProperties

  property :request, accepts: Request
  property :response, accepts: Response
end

