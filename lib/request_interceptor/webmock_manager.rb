class RequestInterceptor::WebMockManager
  WebMockConfigurationCache = Struct.new(:request_stubs, :callbacks, :allow_net_connect, :allow_localhost, :show_body_diff, :show_stubbing_instructions, :enabled_previously)

  def initialize(applications, callback = nil)
    @applications = applications
    @callback = callback
  end

  def run_simulation
    original_webmock_configuration = setup

    yield
  ensure
    teardown(original_webmock_configuration)
  end

  protected

  attr_reader :callback
  attr_reader :applications

  private

  def setup
    original_configuration = WebMockConfigurationCache.new
    original_configuration.enabled_previously = WebMock.enabled?
    original_configuration.request_stubs = WebMock::StubRegistry.instance.request_stubs.dup || []
    original_configuration.callbacks = WebMock::CallbackRegistry.callbacks.dup || []
    original_configuration.allow_net_connect = WebMock::Config.instance.allow_net_connect
    original_configuration.allow_localhost = WebMock::Config.instance.allow_localhost
    original_configuration.show_body_diff = WebMock::Config.instance.show_body_diff
    original_configuration.show_stubbing_instructions = WebMock::Config.instance.show_stubbing_instructions

    WebMock.after_request(&callback) unless callback.nil?

    applications.each do |application|
      WebMock.stub_request(:any, application.pattern).to_rack(application)
    end

    WebMock.allow_net_connect!
    WebMock.hide_body_diff!
    WebMock.hide_stubbing_instructions!
    WebMock.enable!

    original_configuration
  end

  def teardown(original_configuration)
    WebMock::Config.instance.allow_net_connect = original_configuration.allow_net_connect
    WebMock::Config.instance.allow_localhost = original_configuration.allow_localhost
    WebMock::Config.instance.show_body_diff = original_configuration.show_body_diff
    WebMock::Config.instance.show_stubbing_instructions = original_configuration.show_stubbing_instructions
    WebMock::CallbackRegistry.reset
    original_configuration.callbacks.each do |callback_settings|
      WebMock.after_request(callback_settings[:options], &callback_settings[:block])
    end
    WebMock::StubRegistry.instance.request_stubs = original_configuration.request_stubs
    WebMock.disable! unless original_configuration.enabled_previously
  end
end
