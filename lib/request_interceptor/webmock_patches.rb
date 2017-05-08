module RequestInterceptor::WebMockPatches
  def enable!
    @enabled = true
    super
  end

  def disable!
    @enabled = false
    super
  end

  def enabled?
    !!@enabled
  end

  def disabled?
    !enabled
  end
end
