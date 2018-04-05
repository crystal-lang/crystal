require "./severity"

class Logger
  # `Handler` is responsible for accepting log messages, filtering them based
  # on severity, and dispatching them to one or more `Adapter` objects.
  #
  # Each handler internally maintains a hash of components and their
  # associated log levels. Components are simply strings, and are treated
  # hierarchically using "::" as a delimiter. This means that if the level for
  # component "Foo" is set to WARN, then messages from component "Foo::Bar"
  # will also use WARN as their threshold.
  #
  # Most programs will only ever need the default handler provided by
  # `Logger.default_handler`.
  #
  # Example:
  # ```crystal
  # require "logger"
  #
  # module Zoo
  #   class Giraffe
  #     @@logger = Logger.new(name)
  #
  #     # Equivalent to `Logger.default_handler.set_level "Zoo::Giraffe", Logger::DEBUG`
  #     @@logger.level = Logger::DEBUG
  #
  #     def initialize
  #       @@logger.info "A giraffe has arrived."
  #     end
  #   end
  #
  #   class Rhinocerous
  #     @@logger = Logger.new(name)
  #
  #     def initialize
  #       @@logger.info "A rhino has arrived."
  #       @@logger.warn "The rhino is charging!"
  #     end
  #   end
  # end
  #
  # # I only want to hear about problems from most animals:
  # Logger.default_handler.set_level "Zoo", Logger::WARN
  #
  # Zoo::Giraffe.new     # prints "A giraffe has arrived"
  # Zoo::Rhinocerous.new # prints only "The rhino is charging!"
  # ```
  class Handler
    # Each log message that meets this handler's severity level will be output
    # by all of the  adapters in this array.
    property adapters : Array(Adapter)

    # Creates a new handler that will use the given adapter to log messages.
    def self.new(adapter : Adapter, level = DEFAULT_SEVERITY)
      return new([adapter] of Adapter, level)
    end

    # Creates a new handler that will use multiple adapters to log messages.
    def initialize(@adapters : Array(Adapter), level = DEFAULT_SEVERITY)
      @levels = {"" => level} of String => Severity
    end

    # Searches up the component hierarchy to find the effective log level for
    # the given component.
    def level!(component : String = "") : Severity
      if severity = @levels[component]?
        return severity
      end

      parts = component.split "::"
      until parts.empty?
        parts.pop
        if severity = @levels[parts.join "::"]?
          return severity
        end
      end

      # Never executes - @levels[""] should always exist
      raise "No log level found for #{component}"
    end

    # Gets the log level of the given component, returning `nil` if none is
    # set.
    def level?(component : String = "") : Severity?
      @levels[component]?
    end

    # Sets the log level for the given component
    def set_level(component : String, level : Severity) : Nil
      @levels[component] = level
    end

    # Sets the log level for the root component
    def set_level(level : Severity) : Nil
      @levels[""] = level
    end

    # Removes the log level for a given component, causing it to fall back on
    # its parents in the hierarchy. Unsetting the root component (`""`) sets
    # it to INFO.
    def unset_level(component : String = "") : Nil
      if component.empty?
        @levels[""] = DEFAULT_SEVERITY
      else
        @levels.delete component
      end
    end

    # Logs *message* if *severity* meets or exceeds level of *component*.
    def log(severity, message, component = nil)
      component = component.to_s
      return if severity < level!(component)
      @adapters.each &.write(severity, message.to_s, Time.now, component)
    end

    # Logs the message returned from the given block if *severity* meets or
    # exceeds the level of *component*. The block is not run otherwise. This
    # is preferable to passing the message in directly when building the
    # message adds significant overhead.
    def log(severity, component = nil)
      component = component.to_s
      return if severity < level!(component)
      @adapters.each &.write(severity, yield.to_s, Time.now, component)
    end
  end

  def self.default_handler
    @@default_handler ||= Handler.new(IOAdapter.new(STDERR))
  end
end
