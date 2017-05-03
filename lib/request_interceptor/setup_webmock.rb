class RequestInterceptor::SetupWebmock
  WebMockSettings = Struct.new(:request_stubs, :callbacks, :net_connect_allowed, :show_body_diff, :show_stubbing_instructions) do
    alias net_connect_allowed? net_connect_allowed
  end

  def self.perform(applications, callback = nil, &simulation)
    new(applications, callback).perform(&simulation)
  end

  def initialize(applications, callback = nil)
    @applications = applications
    @callback = callback
    @webmock_settings = WebMockSettings.new([], [])
  end

  def perform
    setup_webmock

    yield
  ensure
    reset_webmock
  end

  protected

  attr_reader :webmock_settings
  attr_reader :callback
  attr_reader :applications

  private

  def setup_webmock
    webmock_settings.request_stubs = WebMock::StubRegistry.instance.request_stubs.dup || []
    webmock_settings.callbacks = WebMock::CallbackRegistry.callbacks.dup || []
    webmock_settings.net_connect_allowed = WebMock.net_connect_allowed?
    webmock_settings.show_body_diff = WebMock::Config.instance.show_body_diff
    webmock_settings.show_stubbing_instructions = WebMock::Config.instance.show_stubbing_instructions

    WebMock.after_request(&callback) unless callback.nil?

    applications.each do |pattern, application|
      WebMock.stub_request(:any, pattern).to_rack(application)
    end

    WebMock.allow_net_connect!
    WebMock.hide_body_diff!
    WebMock.hide_stubbing_instructions!
    WebMock.enable!
  end

  def reset_webmock
    WebMock.disable_net_connect! unless webmock_settings.net_connect_allowed?
    WebMock::Config.instance.show_body_diff = webmock_settings.show_body_diff
    WebMock::Config.instance.show_stubbing_instructions = webmock_settings.show_stubbing_instructions
    WebMock::CallbackRegistry.reset
    webmock_settings.callbacks.each do |callback_settings|
      WebMock.after_request(callback_settings[:options], &callback_settings[:block])
    end
    WebMock::StubRegistry.instance.request_stubs = webmock_settings.request_stubs
  end

end
