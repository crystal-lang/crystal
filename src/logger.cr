# The Logger class provides a simple but sophisticated logging utility that you can use to output messages.
#
# The messages have associated levels, such as INFO or ERROR that indicate their importance.
# You can then give the Logger a level, and only messages at that level of higher will be printed.
#
# For instance, in a production system, you may have your Logger set to INFO or even WARN.
# When you are developing the system, however, you probably want to know about the program’s internal state,
# and would set the Logger to DEBUG.
#
# If logging to multiple locations is required, an `IO::MultiWriter` can be
# used.
#
# ### Example
#
# ```crystal
# require "logger"
#
# log = Logger.new(STDOUT)
# log.level = Logger::WARN
#
# log.debug("Created logger")
# log.info("Program started")
# log.warn("Nothing to do!")
#
# begin
#   File.each_line(path) do |line|
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
  property level : Severity
  property progname : String
  property formatter

  # A logger severity level
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
  end

  alias Formatter = String, Time, String, String, IO ->

  private DEFAULT_FORMATTER = Formatter.new do |severity, datetime, progname, message, io|
    io << severity[0] << ", [" << datetime << " #" << Process.pid << "] "
    io << severity.rjust(5) << " -- " << progname << ": " << message
  end

  # :nodoc:
  record Message,
    severity : Severity,
    datetime : Time,
    progname : String,
    message : String

  # Creates a new logger that will log to the given *io*.
  # If *io* is `nil` then all log calls will be silently ignored.
  def initialize(@io : IO?)
    @level = Severity::INFO
    @formatter = DEFAULT_FORMATTER
    @progname = ""
    @closed = false
    @mutex = Mutex.new
  end

  # Calls the *close* method on the object passed to `initialize`
  def close
    return if @closed
    return unless io = @io
    @closed = true

    @mutex.synchronize do
      io.close
    end
  end

  {% for name in Severity.constants %}
    {{name.id}} = Severity::{{name.id}}

    # Returns `true` if the logger's current severity is lower or equal to `{{name.id}}`.
    def {{name.id.downcase}}?
      level <= Severity::{{name.id}}
    end

    # Logs *message* if the logger's current severity is lower or equal to `{{name.id}}`.
    # *progname* overrides a default progname set in this logger.
    def {{name.id.downcase}}(message, progname = nil)
      log(Severity::{{name.id}}, message, progname)
    end

    # Logs the message as returned from the given block if the logger's current severity
    # is lower or equal to `{{name.id}}`. The block is not run if the severity is higher.
    # *progname* overrides a default progname set in this logger.
    def {{name.id.downcase}}(progname = nil)
      log(Severity::{{name.id}}, progname) { yield }
    end
  {% end %}

  # Logs *message* if *severity* is higher or equal with the logger's current
  # severity. *progname* overrides a default progname set in this logger.
  def log(severity, message, progname = nil)
    return if severity < level || !@io
    write(severity, Time.now, progname || @progname, message)
  end

  # Logs the message as returned from the given block if *severity*
  # is higher or equal with the loggers current severity. The block is not run
  # if *severity* is lower. *progname* overrides a default progname set in this logger.
  def log(severity, progname = nil)
    return if severity < level || !@io
    write(severity, Time.now, progname || @progname, yield)
  end

  private def write(severity, datetime, progname, message)
    io = @io
    return unless io

    label = severity == Severity::UNKNOWN ? "ANY" : severity.to_s
    progname_to_s = progname.to_s
    message_to_s = message.to_s
    @mutex.synchronize do
      formatter.call(label, datetime, progname_to_s, message_to_s, io)
      io.puts
      io.flush
    end
  end
end
