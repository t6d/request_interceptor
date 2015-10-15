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
        Net::HTTPResponse::CODE_TO_OBJ.inject(wrapped_classes) do |classes, (code, original_class)|
          new_class = Class.new(original_class) do
            attr_accessor :body
          end

          new_class.define_singleton_method(:name) { original_class.name }
          new_class.define_singleton_method(:to_s) { original_class.name }

          classes[code] = new_class
          classes
        end
      end

    @response_classes[code]
  end
end
