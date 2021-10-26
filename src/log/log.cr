class Log
  getter source : String
  getter backend : Backend?
  @level : Severity?
  # :nodoc:
  property initial_level : Severity

  # :nodoc:
  def initialize(@source : String, @backend : Backend?, level : Severity)
    @initial_level = level
  end

  # :nodoc:
  def changed_level : Severity?
    @level
  end

  def level : Severity
    @level || @initial_level
  end

  # Change this log severity level filter.
  def level=(value : Severity)
    @level = value
    if (backend = @backend).responds_to?(:level=)
      backend.level = value
    end
    value
  end

  # :nodoc:
  def backend=(value : Backend?)
    @backend = value
  end

  # Logs a message if the logger's current `level` is lower or equal to *severity*.
  def log(severity : Severity, *, exception : Exception? = nil)
    return unless level <= severity
    return unless backend = @backend

    dsl = Emitter.new(@source, severity, exception)
    result = yield dsl
    entry =
      case result
      when Entry
        result
      else
        dsl.emit(result.to_s)
      end

    backend.dispatch entry
  end

  {% for severity in %i[trace debug info notice warn error fatal] %}
    # Logs a message if the logger's current `level` is lower or equal to `{{severity}}`.
    def {{severity.id}}(*, exception : Exception? = nil)
      log({{severity}}, exception: exception) do |dsl|
        yield dsl
      end
    end
  {% end %}
end
