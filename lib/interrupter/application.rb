require "sinatra/base"

class Interrupter::Application < Sinatra::Base
  class << self
    attr_accessor :hostname_pattern
  end
end
