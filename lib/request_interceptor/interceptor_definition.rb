require 'delegate'

class RequestInterceptor::InterceptorDefinition < SimpleDelegator
  attr_accessor :hostname_pattern

  def initialize(application, hostname_pattern)
    super(application)
    @hostname_pattern = hostname_pattern
  end
end
