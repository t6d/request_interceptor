require 'spec_helper'

describe RequestInterceptor do
  it 'has a version number' do
    expect(RequestInterceptor::VERSION).not_to be nil
  end

  let(:example) do
    RequestInterceptor.define(/.*\.example.com/) do
      before { content_type 'text/plain' }
      get("/") { "example.com" }
      post("/") { request.body }
      put("/") { request.body }
      delete("/") { halt 202 }
    end
  end

  let(:google) do
    google = RequestInterceptor.define(/.*\.google.com/) do
      before { content_type 'text/plain' }
      get("/") { "google.com" }
    end
  end

  context 'when using the Net::HTTP convenience methods' do
    around do |spec|
      RequestInterceptor.run(example, google) { spec.run }
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
      RequestInterceptor.run(example, google) { spec.run }
    end

    it 'intercepts GET requests' do
      get_request = Net::HTTP::Get.new(uri)
      response = http.request(get_request)
      expect(response).to be_kind_of(Net::HTTPOK)
    end

    it 'intercepts POST request' do
      post_request = Net::HTTP::Post.new(uri)
      post_request.body = 'test'
      response = http.request(post_request)

      expect(response).to be_kind_of(Net::HTTPOK)
      expect(response.body).to eq(post_request.body)
    end

    it 'intercepts PUT requests' do
      put_request = Net::HTTP::Put.new(uri)
      put_request.body = 'test'
      response = http.request(put_request)

      expect(response).to be_kind_of(Net::HTTPOK)
      expect(response.body).to eq(put_request.body)
    end

    it 'intercepts DELETE requests' do
      delete_request = Net::HTTP::Delete.new(uri)
      response = http.request(delete_request)
      expect(response).to be_kind_of(Net::HTTPAccepted)
    end

    it 'runs non-intercepted requests like normal' do
      request = Net::HTTP::Get.new( URI.parse("http://stackoverflow.com/") )
      response = http.request(request)
      expect(response.body).to match /Stack Overflow/im
    end
  end
end
