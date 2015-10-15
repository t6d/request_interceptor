require 'rack/utils'

class RequestInterceptor::Status < Struct.new(:value, :description)
  STATUSES = Rack::Utils::HTTP_STATUS_CODES

  def self.from_code(code, description = nil)
    description = STATUSES.fetch(code.to_i, "Unknown") if description.nil?
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
