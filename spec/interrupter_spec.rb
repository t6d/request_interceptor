require 'spec_helper'

describe Interrupter do
  it 'has a version number' do
    expect(Interrupter::VERSION).not_to be nil
  end

  it 'intercepts GET requests' do
    example = Interrupter.define(/.*\.example.com/) do
      before { content_type 'text/plain' }
      get("/") { "example.com" }
    end

    google = Interrupter.define(/.*\.google.com/) do
      before { content_type 'text/plain' }
      get("/") { "google.com" }
    end

    Interrupter.run(example, google) do
      expect(Net::HTTP.get(URI("http://test.example.com"))).to eq("example.com")
      expect(Net::HTTP.get(URI("http://test.google.com"))).to eq("google.com")

      Net::HTTP.get(URI("http://test.example.com")) do |response|
        expect(response).kind_of?(Net::HTTPOK)
      end
    end
  end
end
