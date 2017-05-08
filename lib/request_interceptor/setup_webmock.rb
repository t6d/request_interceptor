class RequestInterceptor::SetupWebmock
  WebMockSettings = Struct.new(:request_stubs, :callbacks, :allow_net_connect, :allow_localhost, :show_body_diff, :show_stubbing_instructions, :enabled_previously)

  def self.perform(applications, callback = nil, &simulation)
    new(applications, callback).perform(&simulation)
  end

  def initialize(applications, callback = nil)
    @applications = applications
    @callback = callback
  end

  def perform
    settings = setup_webmock

    yield
  ensure
    reset_webmock(settings)
  end

  protected

  attr_reader :callback
  attr_reader :applications

  private

  def setup_webmock
    webmock_settings = WebMockSettings.new
    webmock_settings.enabled_previously = WebMock.enabled?
    webmock_settings.request_stubs = WebMock::StubRegistry.instance.request_stubs.dup || []
    webmock_settings.callbacks = WebMock::CallbackRegistry.callbacks.dup || []
    webmock_settings.allow_net_connect = WebMock::Config.instance.allow_net_connect
    webmock_settings.allow_localhost = WebMock::Config.instance.allow_localhost
    webmock_settings.show_body_diff = WebMock::Config.instance.show_body_diff
    webmock_settings.show_stubbing_instructions = WebMock::Config.instance.show_stubbing_instructions

    WebMock.after_request(&callback) unless callback.nil?

    applications.each do |application|
      WebMock.stub_request(:any, application.pattern).to_rack(application)
    end

    WebMock.allow_net_connect!
    WebMock.hide_body_diff!
    WebMock.hide_stubbing_instructions!
    WebMock.enable!

    webmock_settings
  end

  def reset_webmock(webmock_settings)
    WebMock::Config.instance.allow_net_connect = webmock_settings.allow_net_connect
    WebMock::Config.instance.allow_localhost = webmock_settings.allow_localhost
    WebMock::Config.instance.show_body_diff = webmock_settings.show_body_diff
    WebMock::Config.instance.show_stubbing_instructions = webmock_settings.show_stubbing_instructions
    WebMock::CallbackRegistry.reset
    webmock_settings.callbacks.each do |callback_settings|
      WebMock.after_request(callback_settings[:options], &callback_settings[:block])
    end
    WebMock::StubRegistry.instance.request_stubs = webmock_settings.request_stubs
    WebMock.disable! unless webmock_settings.enabled_previously
  end
end
