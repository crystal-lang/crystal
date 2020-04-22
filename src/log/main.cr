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
    # See `Log#{{method.id}}`.
    def self.{{method.id}}(*, exception : Exception? = nil)
      Top.{{method.id}}(exception: exception) do
        yield
      end
    end
  {% end %}

  @@builder = Builder.new

  # Returns the default `Log::Builder` used for `Log.for` calls.
  def self.builder
    @@builder
  end

  # Returns the current fiber logging context.
  def self.context : Log::Context
    Fiber.current.logging_context
  end

  # Sets the current fiber logging context.
  def self.context=(value : Log::Context)
    Fiber.current.logging_context = value
  end

  # Returns the current fiber logging context.
  def context : Log::Context
    Log.context
  end

  # Sets the current fiber logging context.
  def context=(value : Log::Context)
    Log.context = value
  end

  # Method to save and restore the current logging context.
  #
  # ```
  # Log.context.set a: 1
  # Log.info { %(message with {"a" => 1} context) }
  # Log.with_context do
  #   Log.context.set b: 2
  #   Log.info { %(message with {"a" => 1, "b" => 2} context) }
  # end
  # Log.info { %(message with {"a" => 1} context) }
  # ```
  def self.with_context
    previous = Log.context
    begin
      yield
    ensure
      Log.context = previous
    end
  end

  # :ditto:
  def with_context
    self.class.with_context do
      yield
    end
  end

  class Context
    # Clears the current `Fiber` logging context.
    #
    # ```
    # Log.context.clear
    # Log.info { "message with empty context" }
    # ```
    def clear
      Fiber.current.logging_context = Log::Context.empty
    end

    # Extends the current `Fiber` logging context.
    #
    # ```
    # Log.context.set a: 1
    # Log.context.set b: 2
    # Log.info { %q(message with {"a" => 1, "b" => 2} context") }
    # extra = {:c => "3"}
    # Log.context.set extra
    # Log.info { %q(message with {"a" => 1, "b" => 2, "c" => "3" } context) }
    # extra = {"c" => 3}
    # Log.context.set extra
    # Log.info { %q(message with {"a" => 1, "b" => 2, "c" => 3 } context) }
    # ```
    def set(**kwargs)
      extend_fiber_context(Fiber.current, Log::Context.new(kwargs))
    end

    # :ditto:
    def set(values : Hash(String, V)) forall V
      extend_fiber_context(Fiber.current, Log::Context.new(values))
    end

    # :ditto:
    def set(values : Hash(Symbol, V)) forall V
      extend_fiber_context(Fiber.current, Log::Context.new(values))
    end

    # :ditto:
    def set(values : NamedTuple)
      extend_fiber_context(Fiber.current, Log::Context.new(values))
    end

    private def extend_fiber_context(fiber : Fiber, values : Context)
      context = fiber.logging_context
      fiber.logging_context = context.merge(values)
    end
  end
end
