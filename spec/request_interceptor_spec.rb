require 'spec_helper'

describe RequestInterceptor do
  it 'has a version number' do
    expect(RequestInterceptor::VERSION).not_to be nil
  end

  it 'intercepts GET requests' do
    example = RequestInterceptor.define(/.*\.example.com/) do
      before { content_type 'text/plain' }
      get("/") { "example.com" }
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
    end
  end
end
