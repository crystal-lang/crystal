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

  {% for method in %w(trace debug info notice warn error fatal) %}
    {% severity = method.id.camelcase %}

    # Logs a message if the logger's current severity is lower than or equal to
    # `Severity::{{ severity }}`.
    #
    # The block is not called unless the current severity level would emit a
    # message.
    #
    # Blocks which return `nil` do not emit anything:
    #
    # ```
    # Log.{{method.id}} do
    #   if false
    #     "Nothing will be logged."
    #   end
    # end
    # ```
    def {{method.id}}(*, exception : Exception? = nil)
      severity = Severity::{{severity}}
      return unless level <= severity

      return unless backend = @backend

      dsl = Emitter.new(@source, severity, exception)
      result = yield dsl

      case result
      when Entry
        backend.dispatch result
      when Nil
        # emit nothing
      else
        backend.dispatch dsl.emit(result.to_s)
      end
    end
  {% end %}
end
