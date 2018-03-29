require "./logger/*"

# The `Logger` class provides a simple but sophisticated logging utility that you can use to output messages.
#
# The messages have associated levels, such as `INFO` or `ERROR` that indicate their importance.
# You can then give the `Logger` a level, and only messages at that level of higher will be printed.
#
# For instance, in a production system, you may have your `Logger` set to `INFO` or even `WARN`.
# When you are developing the system, however, you probably want to know about the program’s internal state,
# and would set the `Logger` to `DEBUG`.
#
# ### Example
#
# ```
# require "logger"
#
# log = Logger.new(STDOUT)
# log.level = Logger::WARN
#
# # or
# log = Logger.new(STDOUT, level: Logger::WARN)
#
# log.debug("Created logger")
# log.info("Program started")
# log.warn("Nothing to do!")
#
# begin
#   File.each_line("/foo/bar.log") do |line|
#     unless line =~ /^(\w+) = (.*)$/
#       log.error("Line in wrong format: #{line}")
#     end
#   end
# rescue err
#   log.fatal("Caught exception; exiting")
#   log.fatal(err)
# end
# ```
class Logger
  property adapters : Array(Adapter)

  # A logger severity level.
  enum Severity
    # Low-level information for developers
    DEBUG

    # Generic (useful) information about system operation
    INFO

    # A warning
    WARN

    # A handleable error condition
    ERROR

    # An unhandleable error that results in a program crash
    FATAL

    UNKNOWN

    # Mutes all output when used as a threshold. Logging at this level will produce UNKNOWN.
    SILENT
  end

  DEFAULT_SEVERITY = Severity::INFO

  # Creates a new logger that will log to the given *io*.
  def self.new(io : IO, level = DEFAULT_SEVERITY, program_name = "")
    adapter = IOAdapter.new(io, program_name)
    new([adapter] of Adapter, level)
  end

  # Creates a new logger that will use the given *Adapter* to log messages.
  def self.new(adapter : Adapter?, level = DEFAULT_SEVERITY)
    return new([] of Adapter, level) unless adapter
    return new([adapter] of Adapter, level)
  end

  # Creates a new logger that will use multiple *Adapter*s to log messages.
  def initialize(@adapters : Array(Adapter), level = DEFAULT_SEVERITY)
    @levels = {"" => level} of String => Severity
  end

  # Searches up the component hierarchy to find the log level for the given component.
  def effective_level(component : String = "")
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

    # Should never execute
    raise "No log level found for #{component}"
  end

  # Gets the log level of the given component, returning `nil` if none is set.
  def level(component : String = "")
    @levels[component]?
  end

  # Sets the log level for the root component
  def level=(level : Severity)
    set_level level
  end

  # Sets the log level for the given component
  def set_level(level : Severity, component : String = "") : Nil
    @levels[component] = level
  end

  # Removes the log level for a given component, causing it to fall back on its parents in the hierarchy.
  # Unsetting the root component sets it to INFO.
  def unset_level(component : String = "") : Nil
    if component.empty?
      @levels[""] = DEFAULT_SEVERITY
    else
      @levels.delete component
    end
  end

  {% for name in Severity.constants %}
    {{name.id}} = Severity::{{name.id}}

    # Returns `true` if the logger's current severity is lower or equal to `{{name.id}}`.
    def {{name.id.downcase}}?
      level <= Severity::{{name.id}}
    end

    {% unless name.stringify == "SILENT" %}
      # Logs *message* if the logger's current severity is lower or equal to `{{name.id}}`.
      def {{name.id.downcase}}(message, component = nil)
        log(Severity::{{name.id}}, message, component.to_s)
      end

      # Logs the message as returned from the given block if the logger's current severity
      # is lower or equal to `{{name.id}}`. The block is not run if the severity is higher.
      # This is preferable to passing the message in directly when building the message adds
      # significant overhead.
      def {{name.id.downcase}}(component = nil)
        log(Severity::{{name.id}}, component.to_s) { yield }
      end
    {% end %}
  {% end %}

  # Logs *message* if *severity* is higher or equal with the logger's current severity.
  def log(severity, message, component)
    severity = UNKNOWN if SILENT == severity
    return if severity < effective_level(component)
    @adapters.each &.write(severity, message.to_s, Time.now, component)
  end

  # Logs the message as returned from the given block if *severity*
  # is higher or equal with the loggers current severity. The block is not run
  # if *severity* is lower.
  def log(severity, component)
    severity = UNKNOWN if SILENT == severity
    return if severity < effective_level(component)
    @adapters.each &.write(severity, yield.to_s, Time.now, component)
  end
end
