require 'spec_helper'

describe RequestInterceptor::Matchers::InterceptedRequest do
  it "matches againest the HTTP method and the request path by default" do
    transactions = [
      transaction(:get, "http://example.com/articles"),
      transaction(:post, "http://example.com/articles")
    ]

    matcher = described_class.new("GET", "/articles")

    expect(matcher.matches?(transactions)).to be(true)
  end

  it "supports matching the request count" do
    transactions = [
      transaction(:get, "http://example.com/articles"),
      transaction(:get, "http://example.com/articles")
    ]

    matcher = described_class.new("GET", "/articles").count(2)
    expect(matcher.matches?(transactions)).to be(true)

    matcher = described_class.new("GET", "/articles").count(1)
    expect(matcher.matches?(transactions)).to be(false)
  end


  it "supports matching the request query parameters" do
    transactions = [
      transaction(:get, "http://example.com/articles?param=1"),
      transaction(:get, "http://example.com/articles")
    ]

    matcher = described_class.new("GET", "/articles").with_query(including(param: "1"))
    expect(matcher.matches?(transactions)).to be(true)

    matcher = described_class.new("GET", "/articles").with_query(including(non_existing_param: "1"))
    expect(matcher.matches?(transactions)).to be(false)
  end

  it "supports matching the request body" do
    new_article = {title: "Hello World!", content: "This is my first article."}.to_json
    transactions = [
      transaction(:post, "http://example.com/articles", new_article, "Content-Type" => "application/json"),
    ]

    matcher = described_class.new("POST", "/articles").with_body(including(title: "Hello World!"))
    expect(matcher.matches?(transactions)).to be(true)

    matcher = described_class.new("POST", "/articles").with_body(including(title: "Hello Ruby!"))
    expect(matcher.matches?(transactions)).to be(false)
  end

  it "includes method and path into the description" do
    matcher = described_class.new("POST", "/articles")
    expect(matcher.description).to eq("should intercept a POST request to /articles")
  end

  it "includes expected method, path, query and body in the failure message" do
    matcher = described_class.new("POST", "/articles").with_query(including(id: "1")).with_body(matching("Hello World!"))
    expect(matcher.failure_message).to match("expected: POST /articles with query including {:id => \"1\"} and with body matching \"Hello World!\"")
  end

  it "include similar requests in the failure message; that is request with matching method and path" do
    transactions = [
      transaction(:post, "http://example.com/articles?id=2", "Hello World"),
      transaction(:post, "http://example.com/articles?id=1", "Hola Mundo")
    ]

    matcher = described_class.new("POST", "/articles").with_query(including(id: 1)).with_body(matching("Hello World!"))
    matcher.matches?(transactions)

    expect(matcher.failure_message).to match("got: POST /articles with query {:id=>\"2\"} and with body \"Hello World\"")
    expect(matcher.failure_message).to match("POST /articles with query {:id=>\"1\"} and with body \"Hola Mundo\"")
  end

  it "outputs if no similar request could be found" do
    matcher = described_class.new("POST", "/articles").with_query(including(id: 1)).with_body(matching("Hello World!"))
    expect(matcher.failure_message).to match("got: none")
  end

  it "includes expected method, path, query and body in the negated failure message" do
    matcher = described_class.new("POST", "/articles").with_query(including(id: "1")).with_body(matching("Hello World!"))
    expect(matcher.failure_message_when_negated).to match("intercepted a POST request to /articles with query including {:id => \"1\"} and with body matching \"Hello World!\"")
  end

  private

  def transaction(method, uri, body = nil, headers = {})
    RequestInterceptor::Transaction.new(
      request: RequestInterceptor::Transaction::Request.new(method: method, uri: uri, body: body, headers: headers),
      response: RequestInterceptor::Transaction::Response.new(status_code: 200)
    )
  end
end
