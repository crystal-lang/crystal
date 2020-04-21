class Log
  private Top = Log.for("")

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

  # Define severities as a string so they dont resolve to a `NumberLieral`.
  {% for method, severity in {
                               trace:  "Severity::Trace",
                               debug:  "Severity::Debug",
                               info:   "Severity::Info",
                               notice: "Severity::Notice",
                               warn:   "Severity::Warning",
                               error:  "Severity::Error",
                               fatal:  "Severity::Fatal",
                             } %}

    # Logs a message if the logger's current severity is lower or equal to `{{severity.id}}`.
    #
    # Optionally including the provided *context*, and/or *exception*.
    #
    # The provided *context* is specific to the created `Log::Entry`.
    def {{method.id}}(context : Hash(String | Symbol, _) | NamedTuple | Nil = nil, exception : Exception? = nil, &block : -> _) : Nil
      self.log {{severity.id}}, block, context, exception
    end

    # :ditto:
    def self.{{method.id}}(context : Hash(String | Symbol, _) | NamedTuple | Nil = nil, exception : Exception? = nil, &block : -> _) : Nil
      Top.log {{severity.id}}, block, context, exception
    end

    # Logs a message if the logger's current severity is lower or equal to `{{severity.id}}`.
    #
    # The provided *context* is specific to the created `Log::Entry`.
    def {{method.id}}(exception : Exception? = nil, **context : Log::Context::Type, &block : -> _) : Nil
      self.log {{severity.id}}, block, context, exception
    end

    # :ditto:
    def self.{{method.id}}(exception : Exception? = nil, **context : Log::Context::Type, &block : -> _) : Nil
      Top.log {{severity.id}}, block, context, exception
    end
  {% end %}

  protected def log(severity : Log::Severity, message_block, context : Hash(String | Symbol, _) | NamedTuple | Nil = nil, exception : Exception? = nil) : Nil
    return unless backend = @backend
    return unless level <= severity

    entry = Log.with_context do
      if ctx = context
        Log.context.set ctx
      end

      Entry.new @source, severity, message_block.call.to_s, exception
    end

    backend.write entry
  end
end
