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

  {% for method, severity in {
                               trace:  Severity::Trace,
                               debug:  Severity::Debug,
                               info:   Severity::Info,
                               notice: Severity::Notice,
                               warn:   Severity::Warn,
                               error:  Severity::Error,
                               fatal:  Severity::Fatal,
                             } %}
    # Logs a message if the logger's current severity is lower or equal to `{{severity}}`.
    def {{method.id}}(*, exception : Exception? = nil)
      return unless backend = @backend
      severity = Severity.new({{severity}})
      return unless level <= severity

      dsl = Emitter.new(@source, severity, exception)
      result = yield dsl
      entry =
        case result
        when Entry
          result
        else
          dsl.emit(result.to_s)
        end

      backend.write entry
    end
  {% end %}
end
