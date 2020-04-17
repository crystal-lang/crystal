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

  # Returns `true` if `self` handles logging the provided *severity*.
  def supports?(severity : Log::Severity) : Bool
    level <= severity
  end

  # Define severities as a string so they dont resolve to a `NumberLieral`.
  {% for method, severity in {
                               debug:   "Severity::Debug",
                               verbose: "Severity::Verbose",
                               info:    "Severity::Info",
                               warn:    "Severity::Warning",
                               error:   "Severity::Error",
                               fatal:   "Severity::Fatal",
                             } %}

    # See `Log#{{method.id}}`.
    def self.{{method.id}}(context : Hash | NamedTuple | Nil = nil, exception : Exception? = nil, &block : -> _) : Nil
      Top.log {{severity.id}}, block, context, exception
    end

    # Logs a message if the logger's current severity is lower or equal to `{{severity.id}}`.
    #
    # Optionally including the provided *context*, and/or *exception*.  The context is specific to this entry.
    def {{method.id}}(context : Hash | NamedTuple | Nil = nil, exception : Exception? = nil, &block : -> _) : Nil
      self.log {{severity.id}}, block, context, exception
    end

    # See `Log#{{method.id}}`.
    def self.{{method.id}}(exception : Exception? = nil, **named_args : Log::Context::Type, &block : -> _) : Nil
      Top.log {{severity.id}}, block, named_args, exception
    end

    # Logs a message if the logger's current severity is lower or equal to `{{severity.id}}`.
    #
    # The provided *named_args* are added to the created `Log::Entry` as context specific to this entry.
    #
    # ```
    # # Log some metadata about the user who just logged in
    # Log.info(user_id: user.id, user_name: user.name) { "#{user.name} Logged in" }
    #
    # # Or include metadata about a failed request
    # Log.error(exception, request_id: ctx.request.headers["X-REQUEST-ID"]) { "Unexpected exception #{exception.class}" }
    # ```
    def {{method.id}}(exception : Exception? = nil, **named_args : Log::Context::Type, &block : -> _) : Nil
      self.log {{severity.id}}, block, named_args, exception
    end
  {% end %}

  protected def log(severity : Log::Severity, message_block, context : Hash | NamedTuple | Nil = nil, exception : Exception? = nil) : Nil
    return unless backend = @backend
    return unless self.supports? severity
    message = message_block.call.to_s
    return write_entry backend, severity, message, exception unless (ctx = context)

    Log.with_context do
      Log.context.set ctx
      write_entry backend, severity, message, exception
    end
  end

  private def write_entry(backend : Log::Backend, severity : Log::Severity, message : String, exception : Exception? = nil) : Nil
    backend.write Entry.new @source, severity, message, exception
  end
end
