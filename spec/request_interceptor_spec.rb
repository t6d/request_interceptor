require 'spec_helper'

describe RequestInterceptor do
  it 'has a version number' do
    expect(RequestInterceptor::VERSION).not_to be nil
  end

  let(:example) do
    RequestInterceptor.define do
      before { content_type 'text/plain' }
      before { headers["x-counter"] = env["HTTP_X_COUNTER"].to_i + 1 if env["HTTP_X_COUNTER"] }

      get("/") do
        "example.com"
      end

      post("/") do
        status 201
        request.body
      end

      put("/") do
        status 200
        request.body
      end

      delete("/") do
        halt 202
      end
    end
  end

  let(:google) do
    custom_super_class = Class.new do
      def self.domain
        "google.com"
      end
    end

    RequestInterceptor.define(custom_super_class) do
      def self.call(env)
        [200, {}, [domain]]
      end
    end
  end

  subject(:interceptor) do
    RequestInterceptor.new(/.*\.example\.com/ => example, /.*\.google\.com/ => google)
  end

  it 'should keep a log of all requests and responses' do
    log = interceptor.run do
      Net::HTTP.get(URI("http://test.example.com"))
      Net::HTTP.get(URI("http://test.google.com"))
    end

    expect(log.count).to eq(2)

    expect(log.first.request.path).to eq("/")
    expect(log.first.request.uri).to eq(URI("http://test.example.com"))

    expect(log.last.request.path).to eq("/")
    expect(log.last.request.uri).to eq(URI("http://test.google.com"))
  end

  it 'should normalize urls to remove redundant port information before matching them against the hostname' do
    interceptor = RequestInterceptor.new("example.com" => example)
    log = interceptor.run do
      uri = URI("http://example.com/some/path")
      uri.port = 80

      Net::HTTP.get(uri)
    end

    expect(log.count).to eq(1)
  end

  it 'should allow to customize existing request interceptors' do
    modified_example = example.customize do
      get("/") do
        "example.io"
      end
    end

    modified_example.intercept('example.io') do
      response = Net::HTTP.get(URI("http://example.io/"))
      expect(response).to eq("example.io")
    end
  end

  it 'should allow to set a pre-configured hostname for an application' do
    modified_example = example.customize do
      host "example.io"

      get("/") do
        "example.io"
      end
    end

    modified_example.intercept do
      response = Net::HTTP.get(URI("http://example.io/"))
      expect(response).to eq("example.io")
    end
  end

  it 'should allow to forward arguments to the application intializer' do
    modified_example = example.customize do
      host "example.com"

      attr_reader :language

      def initialize(language = nil)
        @language = language
        super()
      end

      get "/" do
        case language
        when :de
          "Hallo Welt"
        else
          "Hello World"
        end
      end
    end

    modified_example.intercept(:de) do
      response = Net::HTTP.get(URI("http://example.com/"))
      expect(response).to eq("Hallo Welt")
    end

    modified_example.intercept do
      response = Net::HTTP.get(URI("http://example.com/"))
      expect(response).to eq("Hello World")
    end
  end

  context 'when using the Net::HTTP convenience methods' do
    around do |spec|
      interceptor.run { spec.run }
    end

    it 'support .get' do
      expect(Net::HTTP.get(URI("http://test.example.com"))).to eq("example.com")
      expect(Net::HTTP.get(URI("http://test.google.com"))).to eq("google.com")

      Net::HTTP.get(URI("http://test.example.com")) do |response|
        expect(response).kind_of?(Net::HTTPOK)
      end
    end

    it 'supports #post_form' do
      Net::HTTP.post_form(URI("http://test.example.com"), {}) do |response|
        expect(response).kind_of?(Net::HTTPCreated)
      end
    end
  end

  context 'when sending requests through an Net::HTTP instance' do
    let(:uri) { URI.parse("http://test.example.com/") }
    let(:http) { Net::HTTP.new(uri.host) }

    around do |spec|
      interceptor.run { spec.run }
    end

    it 'intercepts GET requests when using Net::HTTP#request directly' do
      get_request = Net::HTTP::Get.new(uri)
      get_request['x-counter'] = '42'
      response = http.request(get_request)
      expect(response).to be_kind_of(Net::HTTPOK)
      expect(response['x-counter'].to_i).to eq(43)
    end

    it 'intercepts GET requests when using Net::HTTP#get' do
      response = http.get(uri.path, 'x-counter' => '42')
      expect(response).to be_kind_of(Net::HTTPOK)
      expect(response['x-counter'].to_i).to eq(43)
    end

    it 'intercepts POST request when using Net::HTTP#request directly' do
      post_request = Net::HTTP::Post.new(uri)
      post_request['x-counter'] = '42'
      post_request.body = 'test'
      response = http.request(post_request)

      expect(response).to be_kind_of(Net::HTTPCreated)
      expect(response.body).to eq(post_request.body)
      expect(response['x-counter'].to_i).to eq(43)
    end

    it 'intercepts POST request when using Net::HTTP#post' do
      body = 'test'
      response = http.post(uri.path, body, 'x-counter' => '42')

      expect(response).to be_kind_of(Net::HTTPCreated)
      expect(response.body).to eq(body)
      expect(response['x-counter'].to_i).to eq(43)
    end

    it 'intercepts PUT requests when using NetHTTP#request directly' do
      put_request = Net::HTTP::Put.new(uri)
      put_request.body = 'test'
      put_request['x-counter'] = '42'
      response = http.request(put_request)

      expect(response).to be_kind_of(Net::HTTPOK)
      expect(response.body).to eq(put_request.body)
      expect(response['x-counter'].to_i).to eq(43)
    end

    it 'intercepts PUT requests when using Net::HTTP#put' do
      body = 'test'
      response = http.put(uri.path, body, 'x-counter' => '42')

      expect(response).to be_kind_of(Net::HTTPOK)
      expect(response.body).to eq(body)
      expect(response['x-counter'].to_i).to eq(43)
    end

    it 'intercepts DELETE requests when using Net::HTTP#request directly' do
      delete_request = Net::HTTP::Delete.new(uri)
      delete_request['x-counter'] = '42'
      response = http.request(delete_request)
      expect(response).to be_kind_of(Net::HTTPAccepted)
      expect(response['x-counter'].to_i).to eq(43)
    end

    it 'intercepts DELETE requests when using Net::HTTP#delete' do
      response = http.delete(uri.path, 'x-counter' => '42')
      expect(response).to be_kind_of(Net::HTTPAccepted)
      expect(response['x-counter'].to_i).to eq(43)
    end

    it 'runs non-intercepted requests like normal' do
      request = Net::HTTP::Get.new(URI.parse("https://example.com/") )
      response = Net::HTTP.new("example.com").request(request)
      expect(response.body).to match(/Example Domain/im)
    end
  end

  context 'with a custom class as application template' do
    let(:template) do
      Class.new(Sinatra::Application) do
        def answer
          42
        end
      end
    end

    around do |spec|
      default_template = RequestInterceptor.template
      RequestInterceptor.template = template
      spec.run
      RequestInterceptor.template = default_template
    end

    specify 'interceptors should inherit from the custom class template' do
      interceptor = RequestInterceptor.define do
        get '/' do
          content_type 'text/plain'
          answer.to_s
        end
      end

      RequestInterceptor.run("example.com" => interceptor) do
        uri = URI.parse("http://example.com/")
        expect(Net::HTTP.get(uri)).to eq("42")
      end
    end
  end

  context 'with a proc as application template' do
    let(:template) do
      proc do
        def answer
          42
        end
      end
    end

    around do |spec|
      default_template = RequestInterceptor.template
      RequestInterceptor.template = template
      spec.run
      RequestInterceptor.template = default_template
    end

    specify "the template should be a subclass of RequestInterceptor::Application" do
      RequestInterceptor.template < RequestInterceptor::Application
    end

    specify 'interceptors should inherit from the custom class template' do
      interceptor = RequestInterceptor.define do
        get '/' do
          content_type 'text/plain'
          answer.to_s
        end
      end

      RequestInterceptor.run("example.com" => interceptor) do
        uri = URI.parse("http://example.com/")
        expect(Net::HTTP.get(uri)).to eq("42")
      end
    end
  end

  context 'when nested' do
    let(:other_example) do
      RequestInterceptor.define do
        get "/" do
          "hijacked"
        end
      end
    end

    specify 'the inner interceptor should serve the request and unregister itself cleanly afterwards' do
      RequestInterceptor.run("example.com" => example) do
        RequestInterceptor.run("example.com" => other_example) do
          expect(Net::HTTP.get(URI("http://example.com/"))).to eq("hijacked")
        end

        expect(Net::HTTP.get(URI("http://example.com/"))).to eq("example.com")
      end
    end

    specify 'the inner interceptor should not log calls handled by the outer interceptor' do
      outer_log = RequestInterceptor.run("outer.com" => example) do
        inner_log = RequestInterceptor.run("inner.com" => example) do
          Net::HTTP.get(URI("http://outer.com/"))
          Net::HTTP.get(URI("http://inner.com/"))
        end

        expect(inner_log.count).to eq(1)
      end

      expect(outer_log.count).to eq(1)
    end
  end
end
