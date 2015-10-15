require 'spec_helper'

describe RequestInterceptor do
  it 'has a version number' do
    expect(RequestInterceptor::VERSION).not_to be nil
  end

  it 'intercepts GET requests' do
    example = RequestInterceptor.define(/.*\.example.com/) do
      before { content_type 'text/plain' }
      get("/") { "example.com" }
      post("/") { halt 201 }
      put("/") { halt 204 }
      delete("/") { halt 202 }
    end

    google = RequestInterceptor.define(/.*\.google.com/) do
      before { content_type 'text/plain' }
      get("/") { "google.com" }
    end

    RequestInterceptor.run(example, google) do
      expect(Net::HTTP.get(URI("http://test.example.com"))).to eq("example.com")
      expect(Net::HTTP.get(URI("http://test.google.com"))).to eq("google.com")

      Net::HTTP.get(URI("http://test.example.com")) do |response|
        expect(response).kind_of?(Net::HTTPOK)
      end

      Net::HTTP.post_form(URI("http://test.example.com"), {}) do |response|
        expect(response).kind_of?(Net::HTTPCreated)
      end

      uri = URI.parse("http://test.example.com/")
      http = Net::HTTP.new(uri.host)

      get_request = Net::HTTP::Get.new(uri)
      response = http.request(get_request)
      expect(response).to be_kind_of(Net::HTTPOK)

      post_request = Net::HTTP::Post.new(uri)
      response = http.request(post_request)
      expect(response).to be_kind_of(Net::HTTPCreated)

      put_request = Net::HTTP::Put.new(uri)
      response = http.request(put_request)
      expect(response).to be_kind_of(Net::HTTPNoContent)

      delete_request = Net::HTTP::Delete.new(uri)
      response = http.request(delete_request)
      expect(response).to be_kind_of(Net::HTTPAccepted)
    end
  end
end
