class Log
  # Creates a `Log` for the given source.
  # If *level* is given, it will override the configuration.
  def self.for(source : String, level : Severity? = nil) : Log
    log = builder.for(source)
    log.level = level if level
    log
  end

  # Creates a `Log` for the given nested source.
  # If *level* is given, it will override the configuration.
  def for(child_source : String, level : Severity? = nil) : Log
    return ::Log.for(child_source) if source.blank?
    return ::Log.for(source) if child_source.blank?
    ::Log.for("#{source}.#{child_source}", level)
  end

  # Creates a `Log` for the given type.
  # A type `Foo::Bar(Baz)` corresponds to the source `foo.bar`.
  # If *level* is given, it will override the configuration.
  def self.for(type : Class, level : Severity? = nil) : Log
    source = type.name.underscore.gsub("::", ".")

    # remove generic arguments
    paren = source.index('(')
    source = source[0...paren] if paren

    ::Log.for(source, level)
  end

  # :ditto:
  def for(type : Class, level : Severity? = nil) : Log
    ::Log.for(type, level)
  end

  private Top = Log.for("")

  {% for method in %i(trace debug info notice warn error fatal) %}
    # See `Log#{{ method.id }}`.
    def self.{{ method.id }}(*, exception : Exception) : Nil
      Top.{{ method.id }}(exception: exception)
    end

    # See `Log#{{ method.id }}`.
    def self.{{ method.id }}(*, exception : Exception? = nil)
      Top.{{ method.id }}(exception: exception) do |dsl|
        yield dsl
      end
    end
  {% end %}

  @@builder = Builder.new

  at_exit { @@builder.close }

  # Returns the default `Log::Builder` used for `Log.for` calls.
  def self.builder : Log::Builder
    @@builder
  end

  # Returns the current fiber logging context.
  def self.context : Log::Context
    Log::Context.new(Fiber.current.logging_context)
  end

  # Sets the current fiber logging context.
  def self.context=(value : Log::Metadata) : Log::Metadata
    Fiber.current.logging_context = value
  end

  # :ditto:
  def self.context=(value : Log::Context) : Log::Metadata
    # NOTE: There is a need for `Metadata` and `Context` setters in
    # because `Log.context` returns a `Log::Context` for allowing DSL like `Log.context.set(a: 1)`
    # but if the metadata is built manually the construct `Log.context = metadata` will be used.
    Log.context = value.metadata
  end

  # Returns the current fiber logging context.
  def context : Log::Context
    Log.context
  end

  # Sets the current fiber logging context.
  def context=(value : Log::Metadata | Log::Context)
    Log.context = value
  end

  # Method to save and restore the current logging context.
  # Temporary context for the duration of the block can be set via arguments.
  #
  # ```
  # Log.context.set a: 1
  # Log.info { %(message with {"a" => 1} context) }
  # Log.with_context(b: 2) do
  #   Log.context.set c: 3
  #   Log.info { %(message with {"a" => 1, "b" => 2, "c" => 3} context) }
  # end
  # Log.info { %(message with {"a" => 1} context) }
  # ```
  def self.with_context(**kwargs, &)
    previous = Log.context
    Log.context.set(**kwargs) unless kwargs.empty?
    begin
      yield
    ensure
      Log.context = previous
    end
  end

  # :ditto:
  def self.with_context(values, &)
    previous = Log.context
    Log.context.set(values) unless values.empty?
    begin
      yield
    ensure
      Log.context = previous
    end
  end

  # :ditto:
  def with_context(**kwargs, &)
    self.class.with_context(**kwargs) do
      yield
    end
  end

  # :ditto:
  def with_context(values, &)
    self.class.with_context(values) do
      yield
    end
  end

  struct Context
    getter metadata : Metadata

    def initialize(@metadata : Metadata)
    end

    # Clears the current `Fiber` logging context.
    #
    # ```
    # Log.context.clear
    # Log.info { "message with empty context" }
    # ```
    def clear : Nil
      Fiber.current.logging_context = @metadata = Log::Metadata.empty
    end

    # Extends the current `Fiber` logging context.
    #
    # ```
    # Log.context.set a: 1
    # Log.context.set b: 2
    # Log.info { %q(message with a: 1, b: 2 context") }
    # h = {:c => "3"}
    # Log.context.set extra: h
    # Log.info { %q(message with a: 1, b: 2, extra: {"c" => "3"} context) }
    # h = {"c" => 3}
    # Log.context.set extra: h
    # Log.info { %q(message with a: 1, b: 2, extra: {"c" => 3} context) }
    # ```
    def set(**kwargs) : Log::Metadata
      extend_fiber_context(Fiber.current, kwargs)
    end

    # :ditto:
    def set(values : Hash | NamedTuple) : Nil
      extend_fiber_context(Fiber.current, values)
    end

    private def extend_fiber_context(fiber : Fiber, values)
      context = fiber.logging_context
      fiber.logging_context = @metadata = context.extend(values)
    end
  end

  # Helper DSL module for emitting log entries with data.
  struct Emitter
    # :nodoc:
    def initialize(@source : String, @severity : Severity, @exception : Exception?)
    end

    # Emits a logs entry with a message, and data attached to
    #
    # ```
    # Log.info &.emit("Program started")                         # No data, same as Log.info { "Program started" }
    # Log.info &.emit("User logged in", user_id: 42)             # With entry data
    # Log.info &.emit(action: "Logged in", user_id: 42)          # Empty string message, only data
    # Log.error exception: ex, &.emit("Oops", account: {id: 42}) # With data and exception
    # ```
    def emit(message : String) : Entry
      emit(message, Metadata.empty)
    end

    def emit(message : String, **kwargs) : Entry
      emit(message, kwargs)
    end

    def emit(message : String, data : Metadata | Hash | NamedTuple) : Entry
      Entry.new(@source, @severity, message, Metadata.build(data), @exception)
    end

    def emit(**kwargs) : Entry
      emit(kwargs)
    end

    def emit(data : Metadata | Hash | NamedTuple) : Entry
      emit("", Metadata.build(data))
    end
  end
end
