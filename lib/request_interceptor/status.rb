class RequestInterceptor::Status < Struct.new(:value, :description)
  STATUSES = {
    "100": "Continue",
    "101": "Switching Protocols",
    "102": "Processing",
    "200": "OK",
    "201": "Created",
    "202": "Accepted",
    "203": "Non-Authoritative Information",
    "204": "No Content",
    "205": "Reset Content",
    "206": "Partial Content",
    "207": "Multi-Status",
    "208": "Already Reported",
    "226": "IM Used",
    "300": "Multiple Choices",
    "301": "Moved Permanently",
    "302": "Found",
    "303": "See Other",
    "304": "Not Modified",
    "305": "Use Proxy",
    "307": "Temporary Redirect",
    "308": "Permanent Redirect",
    "400": "Bad Request",
    "401": "Unauthorized",
    "402": "Payment Required",
    "403": "Forbidden",
    "404": "Not Found",
    "405": "Method Not Allowed",
    "406": "Not Acceptable",
    "407": "Proxy Authentication Required",
    "408": "Request Timeout",
    "409": "Conflict",
    "410": "Gone",
    "411": "Length Required",
    "412": "Precondition Failed",
    "413": "Payload Too Large",
    "414": "URI Too Long",
    "415": "Unsupported Media Type",
    "416": "Range Not Satisfiable",
    "417": "Expectation Failed",
    "421": "Misdirected Request",
    "422": "Unprocessable Entity",
    "423": "Locked",
    "424": "Failed Dependency",
    "425": "Unassigned",
    "426": "Upgrade Required",
    "427": "Unassigned",
    "428": "Precondition Required",
    "429": "Too Many Requests",
    "430": "Unassigned",
    "431": "Request Header Fields Too Large",
    "500": "Internal Server Error",
    "501": "Not Implemented",
    "502": "Bad Gateway",
    "503": "Service Unavailable",
    "504": "Gateway Timeout",
    "505": "HTTP Version Not Supported",
    "506": "Variant Also Negotiates",
    "507": "Insufficient Storage",
    "508": "Loop Detected",
    "509": "Unassigned",
    "510": "Not Extended",
    "511": "Network Authentication Required",
  }

  def self.from_code(code, description = nil)
    description = STATUSES.fetch(code.to_s, "Unknown") if description.nil?
    new(code.to_s, description)
  end

  def response_class
    self.class.response_class(value)
  end

  def self.response_class(code)
    @response_classes ||=
      begin
        wrapped_classes = Hash.new {  Net::HTTPUnknownResponse }
        Net::HTTPResponse::CODE_TO_OBJ.inject(wrapped_classes) do |klasses, (code, klass)|
          klasses[code] = Class.new(klass) do
            def self.name
              ancestors.first.name
            end

            attr_accessor :body
          end
          klasses
        end
      end

    @response_classes[code]
  end
end
