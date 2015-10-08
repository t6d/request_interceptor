require "interrupter/version"

module Interrupter
  def self.define(hostname_pattern, &block)
    Class.new(Application, &block).tap do |app|
      app.hostname_pattern = hostname_pattern
    end
  end

  def self.run(*applications, &simulation)
    Runner.new(*applications).run(&simulation)
  end
end

require "interrupter/application"
require "interrupter/runner"
require "interrupter/status"
