# The Logger class provides a simple but sophisticated logging utility that you can use to output messages.
#
# The messages have associated levels, such as INFO or ERROR that indicate their importance.
# You can then give the Logger a level, and only messages at that level of higher will be printed.
#
# For instance, in a production system, you may have your Logger set to INFO or even WARN.
# When you are developing the system, however, you probably want to know about the program’s internal state,
# and would set the Logger to DEBUG.
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
class Logger(T)
  property :level, :progname, :formatter

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

  # :nodoc:
  DEFAULT_FORMATTER = Formatter.new do |severity, datetime, progname, message, io|
    io << severity[0] << ", [" << datetime << " #" << Process.pid << "] "
    io << severity.rjust(5) << " -- " << progname << ": " << message
  end

  # :nodoc:
  record Message, severity, datetime, progname, message

  def initialize(@io : T)
    @level = Severity::INFO
    @formatter = DEFAULT_FORMATTER
    @progname = ""
    @channel = Channel(Message).new(100)
    @close_channel = Channel(Nil).new
    @closed = false
    @shutdown = false
    spawn write_messages
    at_exit { shutdown }
  end

  def close
    return if @closed
    @closed = true
    shutdown
  end

  {% for name in Severity.constants %}
    {{name.id}} = Severity::{{name.id}}

    def {{name.id.downcase}}?
      level <= Severity::{{name.id}}
    end

    def {{name.id.downcase}}(message, progname = nil)
      log(Severity::{{name.id}}, message, progname)
    end

    def {{name.id.downcase}}(progname = nil)
      log(Severity::{{name.id}}, progname) { yield }
    end
  {% end %}

  def log(severity, message, progname = nil)
    return if severity < level
    enqueue(severity, Time.now, progname || @progname, message)
  end

  def log(severity, progname = nil)
    return if severity < level
    enqueue(severity, Time.now, progname || @progname, yield)
  end

  private def enqueue(severity, datetime, progname, message)
    @channel.send Message.new(severity, datetime, progname, message)
  end

  private def write_messages
    loop do
      msg = Channel.receive_first(@channel, @close_channel)
      if msg.is_a?(Message)
        label = msg.severity == Severity::UNKNOWN ? "ANY" : msg.severity.to_s

        # We write to an intermediate String because the IO might be sync'ed so
        # we avoid some system calls. In the future we might want to add an IO#sync?
        # method to every IO so we can do this conditionally.
        @io << String.build do |str|
          formatter.call(label, msg.datetime, msg.progname.to_s, msg.message.to_s, str)
          str.puts
        end

        @io.flush
      else
        @io.close if @closed
        @close_channel.send(nil)
        break
      end
    end
  end

  private def shutdown
    return if @shutdown
    @shutdown = true
    @close_channel.send(nil)
    @close_channel.receive
  end
end
