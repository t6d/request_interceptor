# Request Interceptor

Request interceptor is a library for simulating foreign APIs using Sinatra applcations.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'request_interceptor'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install request_interceptor

## Usage

Once installed, request interceptors can be defined as follows:

```ruby
app = RequestInterceptor.define do
  get "/" do
    content_type "text/plain"
    "Hello World"
  end
end
```

By default, request interceptors are `Sinatra` applications, but any `Rack` compatible application works.
To intercept HTTP requests, the code performing the request must be wrapped in an `RequestInterceptor#run` block:

```ruby
interceptor = RequestInterceptor.new(/.*example\.com$/ => app)
interceptor.run do
  Net::HTTP.get(URI("http://example.com/")) # => "Hello World"
end
```

`RequestInterceptor` instances are initialized with hash mapping hostname patterns to applications.
The patterns are later matched against the hostname of the URI associated with a particular request.
In case of a match, the corresponding application is used to serve the request.
Otherwise, a real HTTP request is performed.

For the sake of convenience, the code above can be shortened using `RequestInterceptor.run`:

```ruby
log = RequestInterceptor.run(/.*example\.com$/ => app) do
  Net::HTTP.get(URI("http://example.com/")) # => "Hello World"
end
```

In both cases, the result is a transaction log.
Each entry in the transaction log is a `RequestInterceptor::Transaction`.
A transaction is simply request/response pair.
The request can be obtained using the equally named `#request` method.
The `#response` method returns the response that corresponds to the particular request.
The code above would result in a transaction log with one entry:

```ruby
log.count # => 1
log.first.request # => Rack::MockRequest
log.first.response # => Rack::MockResponse
```

### Pre-configured hostnames and interceptor customization

Interceptors further support pre-configured hostnames and customization of existing interceptors:

```ruby
customized_app = app.customize do
  hostname "example.de"

  get "/" do
    content_type "text/plain"
    "Hallo Welt"
  end
end

customized_app.intercept do
  response = Net::HTTP.get(URI("http://example.de/")) # => "Hello World"
  response == "Hallo Welt" # => true
end
```

These two features are only available for Sinatra based interceptors that inherit from `RequestInterceptor::Application`, which is the default for all interceptors that have been defined using `RequestInterceptor.define` if no other template class through `RequestInterceptor.template=` has been configured.

### Constructor argument forwarding

Any arugments provided to the `.intercept` method are forwarded to the interceptor's constructor:

```ruby
multilingual_app = RequestInterceptor.define do
  hostname "example.com"

  attr_reader :language

  def initialize(language = nil)
    @language = language
    super()
  end

  get "/" do
    content_type "text/plain"
    language == :de ? "Hallo Welt" : "Hello World"
  end
end

multilingual_app.intercept(:de) do
  response = Net::HTTP.get(URI("http://example.com/"))
  response == "Hallo Welt" # => true
end

multilingual_app.intercept do
  response = Net::HTTP.get(URI("http://example.com/"))
  response = "Hello World" # => true
end
```

## Contributing

Bug reports and pull requests are welcome on GitHub at (t6d/request_interceptor)[https://github.com/t6d/request_interceptor].

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

